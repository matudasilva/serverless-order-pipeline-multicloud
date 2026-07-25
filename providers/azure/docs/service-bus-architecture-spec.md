# Service Bus Architecture Variant — ORQ-003

## Purpose

This variant preserves the functional intent of the AWS order pipeline while
removing Azure Storage Queue child resources from the critical provisioning
path. It is optimized for a short-lived Azure Free Trial deployment that is
created, validated, and destroyed in one controlled session.

## Functional topology

1. An anonymous HTTP Function validates `order-pipeline-v1` and returns `202`.
2. The ingress Function sends the accepted order to an Azure Service Bus queue.
3. The processor Function consumes the queue with at-least-once delivery,
   bounded retries, and the broker-managed dead-letter queue.
4. The processor writes the order and an outbox event to Cosmos DB.
5. The notifier consumes the Cosmos DB Change Feed, records notification state,
   and sends notification work to a second Service Bus queue.
6. A notification worker or external sink consumes that queue. Delivery remains
   at-least-once and deduplicated by the existing idempotency key.

The HTTP contract, `202` behavior, private processing boundary, persistence,
creation event, notification channel, and idempotency rules remain unchanged.

## AWS intent mapping

| AWS intent | Azure implementation | Native difference |
| --- | --- | --- |
| Public API ingress | Azure Functions HTTP trigger | Function endpoint replaces API Gateway front door |
| SQS order queue | Service Bus queue `orders` | Lock/settlement replaces SQS visibility timeout |
| SQS DLQ | Service Bus native dead-letter subqueue | No separately provisioned poison queue |
| Private Lambda processor | Function App Flex processor | Managed identity and RBAC replace IAM role |
| DynamoDB order/outbox | Cosmos DB SQL containers | Session consistency and Change Feed semantics |
| DynamoDB Streams | Cosmos DB Change Feed | Lease container is managed by the Functions trigger |
| SNS/SQS notification path | Service Bus queue `notifications` | Queue-first channel keeps the ephemeral design simple |

## Service Bus design

- Use one **Basic** Service Bus namespace in the selected deployment region and
  three queues: `orders`, `notifications`, and `notification-failures`. Basic is intentional for this
  disposable queue-only trial; topics, sessions, duplicate detection, and
  premium isolation are out of scope.
- Use broker retry and dead-letter behavior; do not create application-level
  poison queues.
- After five failed notification reconciliation attempts, publish a compact
  terminal-failure envelope to `notification-failures`; this is separate from
  the broker-managed DLQ and provides durable operational evidence.
- Set `maxDeliveryCount = 5` on both queues. A message is dead-lettered after
  the broker observes five unsuccessful delivery attempts; the DLQ is then
  inspected before cleanup.
- Configure an explicit lock duration appropriate for the short processor
  execution and use peek-lock settlement rather than auto-complete assumptions.
- Use managed identity with `Azure Service Bus Data Sender` for producers and
  `Azure Service Bus Data Receiver` for consumers, scoped to the queue.
- Do not use connection strings or shared access keys.
- Use the Azure Functions Service Bus extension with a pinned major version and
  prove the Python v2 programming model, extension version 5 or later,
  `fullyQualifiedNamespace`, `credential = managedidentity`, and explicit
  auto-complete/peek-lock behavior before apply.
- Assign `Azure Service Bus Data Sender` and `Azure Service Bus Data Receiver`
  at queue scope. Include the DLQ receive path in the validation evidence and
  allow for RBAC propagation delay before invoking the functions.

## Storage design

Use one Standard LRS Storage Account for Flex host/deployment storage. Keep
three distinct private deployment containers—one per Function App—to prevent
package overwrite. Keep HTTPS-only, TLS 1.2, and identity-authenticated
access. This removes redundant accounts while preserving package isolation;
the trade-off is that account-scoped host roles expose the other apps' host
metadata and must be accepted explicitly for this ephemeral variant.

The Function Apps must not be created until the deployment container is usable.
The provisioning workflow therefore has an explicit readiness gate between
Storage Account creation and Function App creation. The gate may use a
documented ARM/AzAPI readiness check or an operator-run Azure CLI check using
the already authenticated session; it must not persist credentials or local
identifiers.

## Reliability and idempotency

- Service Bus and Cosmos Change Feed are treated as at-least-once sources.
- The processor uses the order correlation/idempotency key to make duplicate
  writes harmless.
- The notifier uses an outbox notification key and conditional updates to avoid
  duplicate sends.
- Broker delivery count is finite; messages that exceed it are inspected in the
  native DLQ before cleanup.
- No exactly-once guarantee is claimed.

## Cost and lifecycle

Service Bus is not a perpetual free-tier guarantee. The namespace and message
operations are acceptable only for a short-lived test covered by the existing
subscription budget. The Basic namespace SKU and selected region must be
recorded in the plan so the expected trial-credit consumption is reviewable;
no automatic PAYG conversion is authorized. The resource group remains the
cleanup boundary and must be deleted after validation. No diagnostic setting or
deployment step may persist secrets, subscription IDs, tenant IDs, or
connection strings.

## Implementation gates

Before Terraform changes:

1. Independently review this specification and the Service Bus tier/region
   assumptions.
2. Pin the `azurerm`/AzAPI versions and the Functions Service Bus extension.
3. Produce a fresh plan showing the removal of Storage Queue resources and the
   addition of the namespace and two queues.
4. Obtain explicit approval for the plan and a separate approval for apply.

This specification contains no Terraform implementation and performs no Azure
action.

## Independent review status

The first independent review requested the clarifications now recorded above:
Basic queue-only SKU, five-delivery dead-letter threshold, pinned Functions
Service Bus extension and managed-identity settings, queue-scoped RBAC, and
separate deployment containers within the shared host account. The revised
specification is ready for a second approval gate; implementation remains
blocked until that gate is explicitly approved.
