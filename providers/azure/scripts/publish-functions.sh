#!/usr/bin/env bash

# Publish each Azure Function from an isolated staging directory. This prevents
# a previous function's files or the shared Python module from leaking into a
# different deployment package. It intentionally does not print credentials.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash providers/azure/scripts/publish-functions.sh --resource-group <name> --name-prefix <prefix>

Prerequisites:
  - Azure CLI is authenticated to the intended subscription.
  - Azure Functions Core Tools v4 (`func`) is installed.
  - Terraform infrastructure has been applied successfully.

This script publishes ingress, processor, and notifier sequentially with
remote build. It creates only temporary local staging directories.
EOF
}

resource_group=""
name_prefix=""

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

if [[ -z "$resource_group" || -z "$name_prefix" ]]; then
  usage >&2
  exit 2
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) is required." >&2
  exit 1
fi

if ! command -v func >/dev/null 2>&1; then
  echo "Azure Functions Core Tools v4 (func) is required." >&2
  exit 1
fi

az account show --only-show-errors >/dev/null

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_root="$(cd "$script_dir/../src" && pwd)"
staging_root="$(mktemp -d "${TMPDIR:-/tmp}/sop-azure-functions.XXXXXX")"
trap 'rm -rf "$staging_root"' EXIT

for component in ingress processor notifier; do
  app_name="${name_prefix}-${component}"
  stage="$staging_root/$component"

  # Fail before publishing if the selected resource group does not own the
  # expected Function App. This prevents a typo from targeting another stack.
  az functionapp show \
    --resource-group "$resource_group" \
    --name "$app_name" \
    --query name \
    --output tsv \
    --only-show-errors >/dev/null

  mkdir -p "$stage"
  cp -a "$source_root/$component/." "$stage/"
  cp -a "$source_root/common" "$stage/common"

  echo "Publishing $app_name in resource group $resource_group..."
  (
    cd "$stage"
    func azure functionapp publish "$app_name" --python --build remote
  )
done

echo "All Function Apps were published successfully."
