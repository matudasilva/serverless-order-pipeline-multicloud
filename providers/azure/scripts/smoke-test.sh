#!/usr/bin/env bash

# Smoke-test the already deployed Azure pipeline. This test is intentionally
# blocked unless --execute is supplied because it sends one real order message.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash providers/azure/scripts/smoke-test.sh --resource-group <name> --name-prefix <prefix> --execute

The test sends one valid v1 order and one invalid request. It verifies the
expected HTTP status codes and waits for the active Service Bus orders and
notifications queues to return to their pre-test counts.

It does not purge queues, replay DLQ messages, change infrastructure, or read
credentials. Existing DLQ and notification-failures messages are intentionally
left untouched.
EOF
}

resource_group=""
name_prefix=""
execute="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group)
      resource_group="${2:-}"
      shift 2
      ;;
    --name-prefix)
      name_prefix="${2:-}"
      shift 2
      ;;
    --execute)
      execute="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$resource_group" || -z "$name_prefix" || "$execute" != "true" ]]; then
  echo "This smoke test requires --resource-group, --name-prefix, and --execute." >&2
  usage >&2
  exit 2
fi

for command in az curl python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Required command is unavailable: $command" >&2
    exit 1
  fi
done

az account show --only-show-errors >/dev/null

ingress_name="${name_prefix}-ingress"
namespace_name="${name_prefix}sb"
host_name="$(az functionapp show \
  --resource-group "$resource_group" \
  --name "$ingress_name" \
  --query properties.defaultHostName \
  --output tsv \
  --only-show-errors)"

if [[ -z "$host_name" ]]; then
  echo "The expected ingress Function App was not found in the supplied resource group." >&2
  exit 1
fi

queue_count() {
  az servicebus queue show \
    --resource-group "$resource_group" \
    --namespace-name "$namespace_name" \
    --name "$1" \
    --query 'countDetails.activeMessageCount' \
    --output tsv \
    --only-show-errors
}

orders_before="$(queue_count orders)"
notifications_before="$(queue_count notifications)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/sop-azure-smoke.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

valid_status="$(curl --silent --show-error --output "$work_dir/valid.json" \
  --write-out '%{http_code}' \
  --header 'Content-Type: application/json' \
  --data '{"item":"smoke-test","quantity":1}' \
  "https://${host_name}/api/orders")"

python3 - "$work_dir/valid.json" "$valid_status" <<'PY'
import json
import sys

body = json.load(open(sys.argv[1], encoding="utf-8"))
if sys.argv[2] != "202" or body.get("status") != "queued" or not body.get("messageId"):
    raise SystemExit("Valid request did not return v1 202 queued response")
PY

invalid_status="$(curl --silent --show-error --output "$work_dir/invalid.json" \
  --write-out '%{http_code}' \
  --header 'Content-Type: application/json' \
  --data '{"quantity":1}' \
  "https://${host_name}/api/orders")"

python3 - "$work_dir/invalid.json" "$invalid_status" <<'PY'
import json
import sys

body = json.load(open(sys.argv[1], encoding="utf-8"))
if sys.argv[2] != "400" or body.get("status") != "error":
    raise SystemExit("Invalid request did not return v1 400 error response")
PY

deadline=$((SECONDS + 600))
while (( SECONDS < deadline )); do
  orders_now="$(queue_count orders)"
  notifications_now="$(queue_count notifications)"
  if [[ "$orders_now" == "$orders_before" && "$notifications_now" == "$notifications_before" ]]; then
    echo "Smoke test passed: valid 202, invalid 400, and queue counts returned to baseline."
    exit 0
  fi
  sleep 10
done

echo "Smoke test timed out waiting for active queue counts to return to baseline." >&2
echo "Inspect Application Insights and Service Bus counts; do not purge or replay messages without approval." >&2
exit 1
