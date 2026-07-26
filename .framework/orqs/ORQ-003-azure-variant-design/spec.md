---
orq: ORQ-003
title: "Azure serverless order-pipeline variant"
state: Closed Locally
phase: Validate
scope: azure-variant
authored_by:
  - agent: "Codex (GPT-5)"
    role: "retrospective recovery"
updated: 2026-07-26
---

| ORQ | Title | State | Phase | Updated |
|---|---|---|---|---|
| ORQ-003 | Azure serverless order-pipeline variant | Closed Locally | Validate | 2026-07-26 |

## Retrospective status

This record was recovered on 2026-07-26 after the Azure work had already been
merged. It is a traceability artifact, not a claim that a contemporaneous ORQ
plan, independent review, or checkpoint existed. Its sources are the Azure
implementation commits, their merge into `main`, and the sanitized provider
documentation committed with them.

## Objective

Implement a short-lived Azure variant of the shared Order Pipeline v1 using
native services, Terraform, managed identities, bounded cost controls, and
sanitized operational evidence. The implementation must preserve equivalent
responsibilities, rather than copy AWS service names or provider envelopes.

## Delivered scope

| Shared responsibility | Azure delivery |
|---|---|
| Public ingress | HTTP-triggered Azure Function validates the v1 payload and returns `202`. |
| Durable processing | Service Bus `orders` queue, queue-scoped managed-identity RBAC, bounded delivery count, and native DLQ. |
| Processing and persistence | Private processor Function persists an order and outbox record in Cosmos DB. |
| Post-persistence event | Cosmos DB Change Feed triggers the notifier Function. |
| Notification | Service Bus notification queue and notifier state/idempotency handling. |
| Operations | Terraform, Application Insights/Log Analytics configuration, publication and smoke-test scripts, architecture assets, runbook, and incident record. |

The implementation contains no committed credentials, state, subscription or
tenant identifiers, connection strings, or real endpoint evidence.

## Historical implementation evidence

- `a6d24ca` — `feat(azure): add serverless order pipeline`: Terraform root,
  Function sources, tests, publication/smoke scripts, architecture assets, and
  Azure operational documentation.
- `f182387` — `ci(azure): validate infrastructure and telemetry`: Azure CI and
  implementation corrections.
- `3de3601` — merged pull request #1 into `main` on 2026-07-25.

The branch remains available as `orq/ORQ-003-azure-variant-design`; its merge
commit is the durable delivery record. The branch itself is behind subsequent
`main` work and is not the source of current repository status.

## Validation boundary

Recorded sanitized evidence establishes one valid HTTP response of `202`, one
invalid response of `400`, and return of the `orders` and `notifications`
queues to their pre-test active-message counts. It does not prove complete
end-to-end conformance, historical Cosmos contents, notification-recipient
delivery, or current Azure resource state. The deployment was ephemeral; no
resource group from the recorded attempt remains.

## Acceptance record

| ID | Result | Evidence |
|---|---|---|
| AC1 | Met | Azure Terraform, Functions, shared contract/idempotency code, and provider README were merged in `3de3601`. |
| AC2 | Met | Service Bus queue architecture, native DLQ, managed identity, and queue-scoped RBAC are specified and implemented. |
| AC3 | Met | Sanitized smoke record reports valid `202`, invalid `400`, and queue drainage. |
| AC4 | Met with boundary | Deployment/publication failure modes are documented with permanent safeguards and repeatable scripts. |
| AC5 | Partially evidenced | Full persistence/change-feed/notification evidence was not retained; no full v1 conformance claim is made. |
| AC6 | Met | Terraform, test, CI, runbook, architecture, and incident artifacts are versioned under `providers/azure/`. |

## Retrospective decisions

- Terraform owns Azure infrastructure; Function publication is a separately
  approved Core Tools remote-build operation.
- Service Bus uses broker-managed retries and dead-lettering; no exactly-once
  behavior is claimed.
- Cosmos capacity and Flex Consumption behavior remain external Azure
  dependencies, handled through preflight, a controlled test window, and
  explicit cleanup.
- This ORQ is closed as implemented with partial sanitized integration
  evidence. ORQ-004 owns repository-wide conformance wording and comparison.
