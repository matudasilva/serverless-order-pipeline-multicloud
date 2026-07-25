# Azure Infrastructure Incident Resolution — ORQ-003

## Purpose

This is a sanitized, step-by-step record of how the Azure trial deployment
issues were diagnosed and resolved. It preserves the operational reasoning
without exposing subscription identifiers, tenant identifiers, resource names,
endpoints, credentials, connection strings, state files, or test payloads.

This record complements the operational
[deployment and troubleshooting runbook](deployment-and-troubleshooting.md).
The runbook is the procedure for a future deployment; this document explains
why the procedure and Terraform safeguards exist.

## Final outcome

An ephemeral Azure stack was deployed with Terraform in an approved region,
then its three Functions were published with Azure Functions Core Tools remote
build. A controlled smoke test later confirmed the shared v1 ingress contract:
one valid request returned `202`, one invalid request returned `400`, and the
active order and notification queues returned to their pre-test counts.

No credentials or connection strings were added to the repository. No
historical DLQ or diagnostic messages were purged during resolution.

## Resolution timeline

### 1. Start from an isolated Azure branch and a fresh plan

**Symptom:** Applying an earlier saved Terraform plan failed with an
inconsistent dependency lock file.

**Diagnosis:** Saved plans bind to the exact configuration and provider
selections that created them. The plan had been created before the active
provider lock selection was available locally.

**Resolution:** Initialize Terraform, retain the provider lock file, and
create a fresh plan from the unchanged working tree immediately before an
approved apply. Do not reuse plans after `init`, provider changes, branch
changes, or configuration edits.

**Permanent safeguard:** Provider versions are pinned and the runbook treats
saved plans as short-lived artifacts outside version control.

### 2. Treat regional Cosmos capacity as an external prerequisite

**Symptom:** The first Cosmos DB account creation attempt failed with an Azure
regional capacity error, even after zone redundancy was disabled.

**Diagnosis:** Free Tier eligibility and an otherwise valid Terraform
configuration do not reserve regional Cosmos capacity.

**Resolution:** Stop the failed attempt, clean up only the affected resource
group after explicit approval, then select an approved region with available
capacity and use a new globally unique prefix. Do not loop destructive retries
against the same unavailable capacity.

**Permanent safeguard:** Terraform explicitly disables zone redundancy and
uses the Free Tier / low-throughput profile, while the preflight checklist
requires current regional availability confirmation. Regional capacity remains
an Azure platform dependency, not a Terraform defect.

### 3. Separate control-plane creation from code publication

**Symptom:** Infrastructure resources could be created, but Flex Consumption
code publication through the Terraform ZIP/SCM path returned `404`.

**Diagnosis:** A successful Function App resource does not prove that the
tested Flex Consumption SCM ZIP endpoint is available for Terraform-managed
package deployment.

**Resolution:** Remove the unreliable Terraform ZIP deployment mechanism from
the active path. Keep Terraform responsible for infrastructure, identity,
roles, and package composition. Publish Function code separately with Azure
Functions Core Tools and `--build remote` after an explicit publication gate.

**Permanent safeguard:**
[`scripts/publish-functions.sh`](../scripts/publish-functions.sh) stages and
publishes each Function sequentially. It verifies that every intended Function
belongs to the supplied resource group before deployment.

### 4. Package shared Python code in every Function artifact

**Symptom:** The first per-Function packaging approach could omit the shared
`common` Python module.

**Diagnosis:** Each Function is deployed independently, so a source archive
that contains only the application directory cannot import a sibling shared
module.

**Resolution:** Add `common/__init__.py`, `common/contract.py`, and
`common/idempotency.py` to every Terraform archive definition. The publication
script also copies `src/common` into each temporary staging directory.

**Permanent safeguard:** The package composition is explicit in Terraform and
the deployment script uses isolated staging directories, preventing one
Function's files from leaking into another's package.

### 5. Use identity-based Function host storage settings

**Symptom:** A Function host could receive a legacy `AzureWebJobsStorage`
setting with an empty account key, despite the intended managed-identity
configuration.

**Diagnosis:** The legacy full connection-string setting takes precedence over
the identity-prefixed settings. An empty `AccountKey` therefore broke host
storage authentication rather than falling back to managed identity.

**Resolution:** Remove the legacy setting from the deployed Functions and keep
only `AzureWebJobsStorage__accountName` plus
`AzureWebJobsStorage__credential=managedidentity`. Confirm the storage Blob,
Queue, and Table data roles for each system-assigned identity.

**Permanent safeguard:** Terraform declares the identity-prefixed settings and
ignores only provider drift on the provider-injected legacy setting. This avoids
committing storage keys while preventing an empty legacy value from being
managed as application configuration.

### 6. Grant only the Service Bus data roles each Function needs

**Symptom:** A producer or consumer could fail to access a Service Bus queue
even though it had a managed identity.

**Diagnosis:** A managed identity has no data-plane permission until an Azure
Service Bus data role is assigned at a suitable scope.

**Resolution:** Assign queue-scoped roles: ingress sends to the order queue;
the processor receives from it; the notifier receives from the notification
queue and sends to the notification and failure queues as needed.

**Permanent safeguard:** Terraform models each assignment independently at the
queue scope. The Service Bus namespace remains Basic and queues use a maximum
delivery count of five with native DLQ behavior.

### 7. Correct Cosmos native data-plane role scope and permissions

**Symptom:** Cosmos operations were denied or lacked the permissions required
by the processor and Change Feed notifier.

**Diagnosis:** Azure RBAC management roles do not grant Cosmos data-plane
access. Cosmos native roles use database/container resource paths that differ
from the Azure Resource Manager container IDs. The processor also needs item
write operations for its atomic order-and-outbox transaction.

**Resolution:** Define native Cosmos custom roles, convert container scopes to
the required database/container form, and grant only the needed actions for
metadata, processor writes, notifier reads/change feed, leases, and
notification records. Wait for role propagation before testing.

**Permanent safeguard:** The native role definitions and assignments are
Terraform-managed, container-scoped, and do not use account keys.

### 8. Fix the processor's transactional-batch SDK call

**Symptom:** The processor returned Cosmos `400` when persisting the order and
outbox record.

**Diagnosis:** The Python Cosmos SDK expects each create operation as
`("create", (document,))`. The previous tuple shape passed the document in an
unsupported structure.

**Resolution:** Correct both order and outbox batch operations to the SDK's
expected shape. Keep `409` as the expected idempotent duplicate path rather
than turning it into a queue-processing failure.

**Permanent safeguard:** The code fix is retained and the troubleshooting
runbook records the exact safe operation form.

### 9. Avoid unsupported legacy Flex settings

**Symptom:** A legacy worker-runtime application setting conflicted with the
Flex Consumption configuration model.

**Diagnosis:** Flex Consumption selects the worker through the Function App
resource's runtime name and runtime version.

**Resolution:** Keep Python runtime configuration in Terraform and do not set
the legacy `FUNCTIONS_WORKER_RUNTIME` application setting.

**Permanent safeguard:** Terraform defines the runtime directly on the Flex
Consumption resource; Core Tools remote build remains the deployment build
authority.

### 10. Validate with a controlled, non-destructive smoke test

**Symptom:** A resource-creation success did not by itself demonstrate that
the contract and asynchronous path were working.

**Diagnosis:** The deployment needed evidence from the public endpoint and
queue behavior, without purging historical diagnostic data.

**Resolution:** Add
[`scripts/smoke-test.sh`](../scripts/smoke-test.sh), which requires an explicit
`--execute` flag. It verifies the expected Function App in the selected
resource group, sends one valid and one invalid contract request, and waits for
the active order and notification queues to return to their baseline counts.
An Azure CLI response-shape issue was found during the first local execution:
the hostname is under `properties.defaultHostName`. The script was corrected
before the test was repeated.

**Permanent safeguard:** The smoke test does not purge or replay messages and
the runbook records sanitized test evidence and its limits.

## What remains intentionally external

- Cosmos regional capacity and trial eligibility are checked before deployment;
  they cannot be guaranteed by Terraform.
- Azure RBAC propagation is eventually consistent. The operator must wait and
  re-test rather than replace secure identity access with keys.
- Budget alerts and telemetry caps are guardrails, not a hard spending stop.
- Full Cosmos-content and notification-recipient assertions require separately
  approved sanitized evidence; the smoke test proves only the stated contract
  and queue-drainage signals.

## Related documents

- [Deployment and troubleshooting runbook](deployment-and-troubleshooting.md)
- [Free-trial preflight checklist](preflight-checklist.md)
- [Service Bus architecture specification](service-bus-architecture-spec.md)
- [Historical first deployment attempt](deployment-attempt-2026-07-24.md)
