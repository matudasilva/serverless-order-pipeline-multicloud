# Storage and Messaging Alternatives — ORQ-003

## Decision context

Three regions accepted the Storage Account control-plane resources but did not
complete the Blob Container and Storage Queue child resources within the
ephemeral deployment window. The problem is therefore treated as a provisioning
reliability constraint, not as a contract or application-runtime failure.

## Option comparison

| Option | Runtime fit | Free-Trial fit | Main risk |
| --- | --- | --- | --- |
| Keep Storage Queues and retry regions | Functional | Low predictability | Repeated regional provisioning stalls |
| Use Service Bus queues and native DLQ | Strong: retries, DLQ, lock/settlement semantics | Acceptable for short-lived credit budget; not a perpetual free tier | Additional service cost and binding/RBAC migration |
| One Storage Account plus staged bootstrap | Functional and closest to current design | Good after cleanup discipline | Bootstrap/import boundary and weaker pure-Terraform ownership |
| ARM/Bicep nested deployment for Storage children | Functional | Good if ARM completes faster | Eventual consistency can still occur |
| Local Azurite/Cosmos Emulator only | Good for contract tests | Excellent | Does not prove Azure RBAC, Functions hosting, or regional capacity |

## Recommended direction

Use one Standard LRS Storage Account for Function host/deployment storage and
Service Bus for the order and notification channels. Keep Cosmos DB for order
and outbox persistence, and retain managed identity plus least-privilege RBAC.
Service Bus supplies a native dead-letter subqueue, so the application no
longer needs separate Storage Queue poison/failure queues. The ingress still
returns `202`; processor and notifier remain at-least-once and idempotent.

Provisioning should be staged:

1. Terraform creates the resource group, one host Storage Account, Service Bus
   namespace/queues, Cosmos DB, observability, and hosting plans.
2. A bounded readiness check confirms the host deployment container.
3. Functions are created only after the host storage endpoint is usable.
4. A fresh plan is reviewed before any apply.

The readiness step must remain explicitly owned and documented. It must not
store keys, secrets, subscription IDs, or tenant IDs in the repository.

## Trade-offs

- Service Bus changes the queue binding and RBAC inventory but improves retry
  and DLQ semantics.
- One host account reduces resource count and provisioning surface but removes
  per-function host-account isolation.
- A staged readiness gate is less declarative than pure Terraform, but it is
  bounded, observable, and appropriate for a disposable Free Trial experiment.
- Local emulators remain valuable for tests, but they are not a substitute for
  the approved Azure apply gate.

## Gate status

This document is a design comparison only. No Terraform changes, Azure
resources, credentials, apply, destroy, commit, or push are performed by it.
