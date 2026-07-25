# Azure Deployment and Troubleshooting Runbook

This runbook makes the Azure deployment repeatable without storing credentials,
subscription identifiers, tenant identifiers, connection strings, state, or
saved plans in the repository. It applies to the ephemeral Azure implementation
of the Serverless Order Pipeline v1.

## Scope and deployment boundary

Terraform owns the resource group, Functions Flex Consumption hosting,
managed identities, queue and database infrastructure, least-privilege roles,
and observability configuration. Azure Functions code publication is a
separate operation: Flex Consumption package publication through the tested
SCM ZIP path returned `404`, so Terraform must not pretend that a successful
infrastructure apply also publishes runnable code.

After an explicitly approved infrastructure apply, publish code with Azure
Functions Core Tools and remote build:

```bash
bash providers/azure/scripts/publish-functions.sh \
  --resource-group '<local-resource-group-name>' \
  --name-prefix '<local-name-prefix>'
```

The script first verifies that each expected Function App belongs to the named
resource group. It then stages each application independently, copies the
shared `common` module into that application's package, publishes
sequentially, and deletes only its temporary local staging directory. It
neither reads nor writes Terraform state, credentials, or Azure resource
configuration.

## Safe operator sequence

1. Authenticate Azure CLI locally and verify that the intended subscription is
   active. Do not put its ID or tenant ID in files or shell history.
2. Copy `terraform.tfvars.example` to an untracked local `terraform.tfvars`.
   Choose a globally unique `name_prefix`, resource group name, and an approved
   region. Do not reuse a failed or deleting resource name.
3. Initialize and validate the exact working tree to be planned:

   ```bash
   terraform -chdir=providers/azure/envs/dev init
   terraform -chdir=providers/azure/envs/dev fmt -check
   terraform -chdir=providers/azure/envs/dev validate
   ```

4. Create a fresh plan immediately before the approved apply. A saved plan is
   valid only for the same configuration, provider selections, and dependency
   lock file that created it:

   ```bash
   terraform -chdir=providers/azure/envs/dev plan -out /tmp/sop-azure.tfplan
   terraform -chdir=providers/azure/envs/dev apply /tmp/sop-azure.tfplan
   ```

   Do not reuse a plan from `/tmp` after `terraform init`, provider upgrades,
   branch changes, lock-file changes, or configuration edits.
5. Wait for Azure RBAC propagation before exercising managed-identity paths.
   Start with a short smoke test, then publish the three Functions using the
   script above only after that publication gate is approved.
6. Verify a valid HTTP request returns `202`, a malformed request returns
   `400`, the `orders` queue drains, Cosmos contains order and outbox records,
   and the `notifications` queue drains. Inspect the Service Bus DLQ only for
   deliberately failed test messages.
7. Teardown remains a separate explicit approval. Before it, retain only
   sanitized evidence and remove any deliberately injected test messages with
   a separately approved operation.

## Controlled smoke test

The repository provides a smoke test for an already deployed stack. It sends
one real valid order, so it is deliberately blocked unless the operator passes
`--execute` after a separate approval:

```bash
bash providers/azure/scripts/smoke-test.sh \
  --resource-group '<local-resource-group-name>' \
  --name-prefix '<local-name-prefix>' \
  --execute
```

The test obtains the ingress hostname from the named resource group, records
the baseline active-message counts for `orders` and `notifications`, then
checks the v1 `202` and `400` HTTP responses. It waits up to ten minutes for
both active queues to return to their pre-test counts. It does not purge,
replay, or inspect message bodies; existing DLQ and diagnostic messages remain
untouched. Queue drainage is integration evidence, not a substitute for
sanitized Cosmos and Application Insights evidence when full conformance is
required.

## Terraform safeguards included in this implementation

- Provider versions are pinned in `versions.tf` and must be reconciled through
  `terraform init`; the lock file is part of the configuration used to create a
  saved plan.
- The package data sources include `host.json`, pinned dependencies, and every
  shared Python source file. This prevents a deployed Function from failing
  because `common` was missing from its package.
- Function host storage uses managed-identity settings
  (`AzureWebJobsStorage__accountName` and
  `AzureWebJobsStorage__credential=managedidentity`). Terraform ignores the
  provider-injected legacy `AzureWebJobsStorage` setting, which otherwise can
  contain an empty key and override the identity-based settings.
- Application Insights is linked through a Terraform resource reference, never
  a literal source value. The connection string is sensitive runtime
  configuration and is not committed.
- Core Tools may create the Flex deployment-storage setting during remote
  publication. Terraform ignores that platform-managed setting so a later
  infrastructure apply does not remove it or disclose its value.
- Service Bus roles are scoped to individual queues. The processor receives
  only from `orders`; ingress sends only to `orders`; notifier receives from
  and sends only to its notification queues.
- Cosmos native data roles are scoped to the containers they require. The
  processor role includes item write operations required by the transactional
  order-and-outbox batch.
- Cosmos zone redundancy is explicitly disabled and the account uses Free Tier
  with 400 RU/s provisioned throughput. This limits the intended trial profile
  but cannot reserve regional capacity.

## Symptom-based recovery

| Symptom | Cause observed | Recovery and prevention |
| --- | --- | --- |
| `Inconsistent dependency lock file` when applying a saved plan | The plan was created with a different provider selection or `.terraform.lock.hcl`. | Run `terraform init`, create a new plan from the unchanged working tree, review it, then apply that new plan. Never apply a plan made before an init, provider update, or branch/configuration change. |
| Cosmos account creation returns `ServiceUnavailable` or a regional capacity message | Azure regional capacity is not guaranteed, including for trial accounts. | Stop the apply, let Terraform report the partial state, select an approved supported region with capacity, use a new globally unique prefix, and plan again. Do not repeatedly recreate the whole stack or broaden permissions as a workaround. |
| Storage or a resource group remains in `Deleting` | Azure control-plane deletion is asynchronous. | Wait until the resource group is absent before reusing its name. Use a new prefix for an approved parallel retry; do not manually import half-deleted resources into state. |
| Flex deployment through Terraform ZIP/SCM returns `404` | The tested Flex Consumption SCM package endpoint was unavailable for this deployment method. | Keep Terraform responsible for infrastructure only and publish via `publish-functions.sh`, which uses Core Tools remote build. Do not reintroduce `zip_deploy_file` until this path is independently retested. |
| A Function starts but fails with `ModuleNotFoundError: common` | A per-function deployment archive omitted shared Python code. | Use the publication script, which stages one isolated package per Function and copies `src/common`. The Terraform archive data sources also model the complete package. |
| Function host storage authentication fails despite identity roles | A legacy `AzureWebJobsStorage` application setting with an empty `AccountKey` can override identity-prefixed settings. | Confirm the legacy setting is absent, retain the two identity settings, and recheck the Storage Blob, Queue, and Table data roles. The Terraform lifecycle rule prevents provider drift on that legacy setting. |
| Processor messages reach the Service Bus DLQ after five deliveries | The Function raised an exception or its queue receiver role was absent. | Inspect Application Insights and the Function invocation first. Verify `Azure Service Bus Data Receiver` on the `orders` queue, then fix the underlying error and replay only explicitly chosen test messages. `max_delivery_count = 5` is intentional. |
| Processor returns Cosmos `400` during the atomic write | The Python SDK transactional batch operation was passed the wrong tuple shape. | Keep the corrected form `("create", (document,))` for both order and outbox documents. A `409` is the expected idempotency path and must not be treated as a delivery failure. |
| Cosmos request is denied for a managed identity | Azure RBAC control-plane roles do not grant Cosmos data-plane access, or native roles have not propagated. | Verify the custom Cosmos native role assignments and their `/dbs/.../colls/...` scope. Wait for propagation before re-running a smoke test; do not add account keys or connection strings. |
| Function configuration rejects `FUNCTIONS_WORKER_RUNTIME` | Flex Consumption chooses the worker from Terraform's `runtime_name` and `runtime_version`. | Do not add the legacy worker-runtime app setting. Keep runtime configuration in the `azurerm_function_app_flex_consumption` resource. |
| A local Python version warning appears during publication | Local Core Tools and the Function runtime can differ. | Use `--build remote`, which builds dependencies for the configured remote runtime. Matching local Python 3.11 is recommended for local testing, but remote build remains the deployment authority. |

## Cost and lifecycle controls

- Azure Free Account credit, Service Bus Basic usage, Functions execution,
  telemetry ingestion, and Cosmos consumption are not a guarantee of zero
  cost. Budget alerts are informational and do not stop resources.
- Keep the test window short. The `lifecycle = ephemeral-free-trial` tag,
  Standard LRS storage, short Log Analytics retention, and daily telemetry cap
  are guardrails rather than a spending limit.
- The Cosmos Free Tier allowance applies only as Azure defines it for the
  subscription. Confirm eligibility before every new account creation.

## Sanitized smoke-test evidence

| Date | Scope | Result | Evidence retained | Exclusions |
| --- | --- | --- | --- | --- |
| 2026-07-25 | Existing ephemeral Azure stack | Passed | One valid v1 request returned `202`; one invalid v1 request returned `400`; the active `orders` and `notifications` queue counts returned to their pre-test baselines. | No resource names, subscription or tenant identifiers, credentials, connection strings, message bodies, DLQ purge, replay, `apply`, or `destroy`. |

This smoke test demonstrates the public contract responses and the observed
asynchronous queue drainage. It does not by itself prove full historical
delivery, Cosmos record contents, or notification recipient delivery. Those
claims require separately approved, sanitized evidence.

## Non-goals

This runbook does not authorize resource creation, provider registration,
credential generation, queue purge, plan application, or teardown. Each
cloud-mutating action requires its own explicit approval.
