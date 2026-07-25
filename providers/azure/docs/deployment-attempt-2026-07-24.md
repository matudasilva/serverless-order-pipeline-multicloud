# Deployment Attempt Record — 2026-07-24

## Outcome

The approved ephemeral deployment was attempted and then fully cleaned up.
The resource group `sop-azure-dev` no longer exists. No Azure resources from
this attempt remain; the subscription-level budget is separate and remains.

## Findings

1. The initial Cosmos DB attempt in `eastus` failed because the region reported
   high demand for Cosmos account capacity. Explicitly disabling zone
   redundancy did not make the account creation reliable.
2. The stack was moved to `eastus2`, where Flex Consumption and Python 3.12
   were available.
3. Cosmos DB creation succeeded in `eastus2`, but AzureRM repeatedly waited for
   the Storage Blob Data Plane after Storage Accounts had been accepted by the
   control plane. The wait exceeded twenty minutes during concurrent creation
   and exceeded twelve minutes during a serialized retry.
4. Interrupting Terraform left state and resource convergence inconsistent;
   the resource group was deleted and verified absent to avoid leaving trial
   resources or charges active.

## Historical boundary

- No `terraform.tfstate` or plan is tracked in the repository.
- No Azure resource group from this attempt remains.
- This record describes only the 2026-07-24 attempt. It does not describe the
  later Central US implementation or its current resource state.
- The current Terraform defaults and the repeatable deployment procedure are
  maintained in [`deployment-and-troubleshooting.md`](deployment-and-troubleshooting.md).
