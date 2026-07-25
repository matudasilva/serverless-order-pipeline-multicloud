# Storage Provisioning Alternative — ORQ-003

## Context

The first ephemeral deployment attempt reached the Azure control plane but
AzureRM remained blocked while polling the Storage Blob Data Plane. The wait
was not caused by the application code or by a missing credential, and it
persisted after changing the region and serializing resource creation.

## Proposed change

Keep the shared order-pipeline contract and the current Azure topology. Replace
only the AzureRM Storage Account, Blob Container, and Storage Queue resources
with ARM/AzAPI control-plane resources:

- create the four Standard/LRS Storage Accounts through `Microsoft.Storage`;
- create the private deployment containers through the Blob Service child
  resource type;
- create the four Storage Queues through the Queue Service child resource type;
- expose deterministic resource IDs, endpoints, and names to the existing
  Function App and RBAC resources.

The `azurerm` provider remains responsible for the resource group, observability,
Cosmos DB, Function hosting, identities, and role assignments. The `azapi`
provider is used only where AzureRM's data-plane readiness polling is the
deployment bottleneck.

The underlying child resource types are supported by Azure Resource Manager:
[Blob containers](https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/2019-06-01/storageaccounts/blobservices/containers)
and [Storage queues](https://learn.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts/queueservices/queues).
The provider version and API versions remain implementation-gate decisions.

## Why this preserves the design

This is a provisioning implementation change, not a runtime topology change.
The ingress, retry/DLQ, private processor, order persistence, creation event,
notifier, and notification channel remain unchanged. Runtime access continues
to use managed identity and least-privilege data-plane RBAC; no keys or
connection strings are introduced.

## Free-tier and ephemeral constraints

- Storage remains Standard LRS with no premium or geo-replicated SKU.
- The deployment remains disposable and is deleted after validation.
- No Azure resource is created by this document.
- No subscription, tenant, secret, endpoint credential, or local variable is
  recorded in the repository.
- The existing subscription budget remains the cost guardrail; the resource
  group is still the cleanup boundary.

## Risks and validation gates

1. Provider schema and API-version support must be validated locally before a
   plan is produced.
2. The generated IDs must match the scopes expected by the existing RBAC
   assignments and Function App settings.
3. A fresh `terraform plan` must be reviewed; no previous saved plan is
   reusable after this configuration change.
4. The independent review must confirm that the replacement does not widen
   identity permissions or alter the runtime contract.
5. Only after an explicit apply approval may the ephemeral deployment be
   attempted again, followed by an explicit cleanup check.

## Alternatives not selected

- Waiting longer on AzureRM: unreliable for a short-lived Free Trial test.
- Provisioning with ad-hoc CLI commands: creates drift and weakens Terraform
  ownership unless every object is imported and reconciled.
- Removing the per-function host storage accounts: reduces the data-plane
  surface but changes the intended isolation and RBAC model.

## Independent review checkpoint

The independent review found no topology or contract blocker and approved this
bounded direction with implementation conditions:

- pin the AzAPI provider and every ARM API version;
- declare explicit account -> service -> child-resource dependencies;
- validate exported IDs/endpoints and the Flex deployment-container URL;
- preserve TLS 1.2, HTTPS-only behavior, private containers, and identity-based
  access;
- prove poison-queue ownership, eventual-consistency handling, and cleanup.

Status: design approved for the implementation gate; Terraform changes and
Azure actions still require explicit approval.
