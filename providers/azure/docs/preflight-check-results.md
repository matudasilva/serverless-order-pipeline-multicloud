# Azure Preflight Check Results

Date: 2026-07-24

These results are sanitized and contain no subscription, tenant, account, or
credential identifiers.

## Read-only checks completed

| Check | Result | Evidence |
|---|---|---|
| Flex Consumption region | PENDING | `centralus` is the next candidate after the East US/East US 2 deployment issues; it must be rechecked before apply. |
| Python runtime in `centralus` | PENDING | Runtime listing must be rechecked for the final region before apply. |
| Selected Terraform runtime | PASS | The implementation selects Python 3.12, which was listed for the target region. |
| Trial credit and duration | PASS (operator confirmation) | The operator confirmed that the subscription shows USD 200 and 30 days. The exact expiration date remains to be recorded. |
| Existing Cosmos DB accounts | PASS (read-only) | No Cosmos DB accounts were returned in the current subscription; no existing account was observed consuming the Free Tier allowance. |
| Required resource providers | PASS (operator-authorized) | `Microsoft.DocumentDB`, `Microsoft.Web`, and `Microsoft.Storage` were registered and verified. This changed subscription provider metadata only; no Azure resources were created. |
| Terraform remote plan | PASS (read-only) | With ephemeral subscription/tenant environment variables, the plan completed with 57 creates, 0 changes, and 0 destroys. No apply was run. |
| Provider constraints | PASS (implementation correction) | Log Analytics retention is 30 days and Flex `maximum_instance_count` is 40, matching the provider's enforced ranges. |
| Resource creation | NOT RUN | No resources were created or changed. |

## Still requires subscription-specific evidence

- Cosmos DB Free Tier eligibility and the one-account allowance.
- Remaining trial credit, expiration date, and spending-limit state.
- Flex Consumption quota and permission to create three apps and scoped RBAC.
- Availability of every selected SKU/capability at deployment time.

These checks must be completed before any Terraform plan or apply. The current
result is a regional/runtime pass, not authorization to deploy.
