# Azure Free-Trial Preflight Checklist

This checklist is a read-only gate before any Azure resource creation. It is
for a new Azure Free account used for a short-lived test and does not authorize
login, provider registration, Terraform plan/apply, deployment, or teardown.

## Account and lifecycle

- [ ] Confirm the subscription is still covered by the Azure Free Account offer,
  with remaining trial credit and a known 30-day expiration date.
- [ ] Confirm that automatic conversion to pay-as-you-go is disabled unless
  explicitly approved for this experiment.
- [ ] Record the intended test window, owner, teardown deadline, and a hard stop
  time earlier than the credit or offer expiration.
- [ ] Confirm that the subscription has no other resources that could be
  affected by the teardown resource-group boundary.

## Region and quota

- [ ] Verify that the selected region supports Linux Flex Consumption (`FC1`)
  for Python 3.11 at the time of deployment.
- [ ] Verify that the region supports the required Storage, Queue Storage,
  Application Insights, Log Analytics, and Cosmos DB capabilities.
- [ ] Verify that the subscription permits three Flex Consumption apps and the
  required managed identities and role assignments.
- [ ] Record the result and date of each availability check; do not infer
  availability from a different subscription or region.

## Free-tier and cost controls

- [ ] Confirm that the Cosmos DB account can be created with Free Tier enabled
  and that no other account already consumes the subscription's one-account
  Free Tier allowance.
- [ ] Confirm the selected provisioned throughput remains within the Free Tier
  boundary and does not use serverless mode.
- [ ] Confirm all storage accounts are Standard LRS and that no premium SKU,
  zone redundancy, private endpoint, NAT gateway, or always-ready Function
  instances are selected. Flex's `maximum_instance_count` is a scale ceiling,
  not a provisioned instance count.
- [ ] Create a conservative budget and alert for the test resource group,
  documenting that alerts do not stop spend.
- [ ] Set the Log Analytics daily ingestion cap and document that it can discard
  telemetry; it is not a billing cap.

## Identity and deployment prerequisites

- [ ] Confirm the deploying operator can create the resource group, managed
  identities, scoped Azure RBAC assignments, and Cosmos native data-plane roles.
- [ ] Confirm each Function App will use system-assigned managed identity for
  host storage, queues, Cosmos DB, and its private deployment container.
- [ ] Confirm the package ZIP contains `host.json` at its root and includes all
  required Python dependencies through the pinned `requirements.txt` and the
  shared `common` module.
- [ ] Install Azure Functions Core Tools v4 and confirm remote build is
  available. Terraform provisions infrastructure; code publication is a
  separately approved Core Tools operation.
- [ ] Confirm the selected Azure Functions Cosmos DB binding version and Python
  runtime support the Change Feed trigger with `/id` leases and managed
  identity before using the real deployment.

## Pre-cloud repository checks

- [ ] `terraform fmt -check` passes.
- [ ] `terraform init -backend=false` and `terraform validate` pass without
  Azure credentials.
- [ ] Python compile and unit tests pass.
- [ ] Secret and identifier scans find no subscription IDs, tenant IDs, access
  keys, connection strings, credentials, local tfvars, state, or build output.
- [ ] Azure diagram source and PNG are present; AWS and GCP diagrams are
  unchanged.

## Evidence and teardown readiness

- [ ] Prepare a test evidence directory outside version control before the
  first cloud operation.
- [ ] Define the exact portable v1 requests and expected 202/400/503 results.
- [ ] Define evidence for Service Bus retries and DLQ, Cosmos order/outbox,
  Change Feed dispatch, notification deduplication, and failure reconciliation.
- [ ] Define the teardown command and verification steps, but do not execute
  them until the test gate is approved.
- [ ] After teardown, verify the resource group is empty/deleted and retain only
  sanitized evidence with no credentials or subscription identifiers.

## Gate decision

The preflight is **ready** only when every applicable checkbox has evidence and
the remaining action is explicitly approved. Any failed availability, quota,
Free Tier, identity, or binding check returns the work to design review; it
must not be bypassed by broadening permissions or changing the contract.
