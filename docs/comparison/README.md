# Multicloud Comparison

This comparison maps responsibilities, not service names. It records only
repository evidence and distinguishes observed facts from design decisions,
limitations, and future work. It does not claim exactly-once delivery or full
end-to-end conformance where evidence is incomplete.

## Responsibility mapping

| Responsibility | AWS baseline | GCP variant | Azure variant |
|---|---|---|---|
| HTTP ingress | API Gateway direct SQS integration | Public Cloud Run ingress | Public Azure Function |
| Durable message | SQS | Pub/Sub topic and push subscription | Service Bus queue |
| Failure path | SQS DLQ | Pub/Sub DLQ topic and inspection subscription | Service Bus native DLQ |
| Processor | Lambda | Private Cloud Run service | Private Function |
| Persistence | DynamoDB | Firestore Native | Cosmos DB SQL containers |
| Post-persistence event | DynamoDB Streams | Firestore-created Eventarc event | Cosmos DB Change Feed |
| Notification | SNS email subscription | Pub/Sub notification topic | Service Bus notification queue and logical sink |
| Observability | CloudWatch Logs | Cloud Logging and Monitoring | Application Insights and Log Analytics |

## Security and identity

**Observed fact:** AWS scopes API Gateway, Lambda, SQS, DynamoDB, and SNS IAM
permissions to resource ARNs, except for the documented account-level API
Gateway CloudWatch role requirement. GCP uses service accounts, private
processor/notifier services, and narrowly assigned IAM roles. Azure uses
managed identities, queue-scoped Service Bus roles, and Cosmos native
data-plane roles; management-plane RBAC alone is insufficient for Cosmos data.

**Design decision:** no provider stores long-lived keys, connection strings,
or credentials in the repository. Azure telemetry receives its connection
string from a sensitive Terraform value rather than a literal source value.

**Limitation:** IAM and RBAC propagation are eventually consistent operational
dependencies; successful Terraform validation does not prove live data-plane
access.

## Delivery semantics

All providers use at-least-once delivery paths. Duplicates remain possible and
ordering is not a portable guarantee.

- AWS documents SQS partial batch failures and a DLQ after five failures.
- GCP documents a Pub/Sub push subscription with a DLQ policy and Eventarc
  delivery after Firestore persistence; duplicate observations must be recorded.
- Azure documents Service Bus delivery counts and native DLQ behavior; its
  processor and notifier use idempotency-oriented Cosmos records.

**Future work:** record equivalent deliberate-failure evidence for retry, DLQ,
duplicate behavior, persistence, and notification per provider.

## Operability and cost boundaries

**Observed facts:** GCP separates bootstrap from workload and verified teardown
after manual validation. Azure separates Terraform infrastructure from Function
publication because the tested Flex ZIP/SCM route was unreliable; it records
regional Cosmos capacity and RBAC propagation as operational constraints. AWS
retains its direct API Gateway-to-SQS integration and historical teardown
evidence.

**Cost guardrails:** budgets, free-tier quantities, and trial credit are
guardrails, not cost-zero guarantees or hard spending limits. Resources must be
destroyed after approved testing; current and historical deployment evidence is
not a claim that resources are presently running.

## Conformance status

The shared contract remains the target contract. AWS is explicitly
non-conformant. GCP and Azure implement its ingress shape, but the repository
does not yet contain complete portable-case evidence across HTTP, persistence,
notification, and DLQ/retry layers. The portable runner will close only the
HTTP-evidence gap; provider-specific integrations remain separate evidence.
