# Shared Order Pipeline Contract v1

## Purpose and status

This document defines the provider-neutral functional contract for the order
pipeline. AWS is the current functional baseline, but its native request,
queue, database-stream, and notification representations are implementation
details. GCP and Azure implementations must meet the responsibilities below,
not mirror AWS service names or event envelopes.

This is a target contract. The existing AWS baseline accepts and stores the
raw request body and returns `200` with a provider message identifier; it does
not yet validate this v1 schema or return the v1 `202` response. An explicit
AWS change is required before it may be claimed as v1-conformant.

## HTTP ingress

The public endpoint is `POST /orders` with `Content-Type: application/json`.

### Request body

```json
{
  "item": "widget",
  "quantity": 3
}
```

| Field | Type | Rules |
|---|---|---|
| `item` | string | Required; trimmed, non-empty, maximum 256 characters. |
| `quantity` | integer | Required; greater than zero. |

Additional fields may be accepted and preserved by a provider, but are outside
the portable contract. Providers must reject malformed JSON and bodies that do
not satisfy the required fields. The contract has no authentication,
idempotency, pricing, or inventory-reservation semantics.

### Response

A successfully accepted request returns `202 Accepted`:

```json
{
  "status": "queued",
  "messageId": "provider-generated-correlation-id"
}
```

`messageId` must be non-empty and allow the provider to correlate the accepted
message with logs or queue evidence. It is not a portable order identifier.

Invalid input returns `400 Bad Request` with:

```json
{
  "status": "error",
  "message": "human-readable validation message"
}
```

Failures while accepting a valid request return `5xx` and must not report
`status: "queued"`.

## Processing responsibilities

For each accepted message, every provider implementation must provide these
responsibilities in order:

1. Durably enqueue the accepted order and isolate poison messages with a DLQ
   or equivalent failure path.
2. Process the order asynchronously and persist it with a provider-generated,
   immutable `orderId`.
3. Emit a post-persistence event only after a successful persistence.
4. Consume that event and publish one notification for the newly persisted
   order.

The same accepted request may be delivered more than once by underlying
messaging. Idempotent persistence is not part of v1; each provider must state
its observed duplicate behavior and its DLQ/retry policy in provider
documentation.

## Portable test payloads

| Case | Request body | Expected result |
|---|---|---|
| `valid-minimal` | `{ "item": "widget", "quantity": 1 }` | `202`, `status: "queued"`, non-empty `messageId`; eventually one persisted order and one notification. |
| `valid-typical` | `{ "item": "notebook", "quantity": 3 }` | Same as `valid-minimal`. |
| `invalid-missing-item` | `{ "quantity": 1 }` | `400`; no queued message, persisted order, or notification. |
| `invalid-blank-item` | `{ "item": "   ", "quantity": 1 }` | `400`; no queued message, persisted order, or notification. |
| `invalid-quantity-zero` | `{ "item": "widget", "quantity": 0 }` | `400`; no queued message, persisted order, or notification. |
| `invalid-quantity-type` | `{ "item": "widget", "quantity": "3" }` | `400`; no queued message, persisted order, or notification. |
| `invalid-json` | `{ "item": ` | `400`; no queued message, persisted order, or notification. |

The eventual assertions in successful cases are manual integration evidence
until each provider supplies automated end-to-end tests. A test run records the
HTTP response, persisted `orderId`, notification evidence, retry/DLQ result if
applicable, provider, region, and timestamp.

## Provider conformance record

Before declaring a provider conformant, its documentation must identify:

- its ingress, message queue, DLQ, compute, persistence, post-persistence
  event, and notification services;
- the correlation from `messageId` to provider logs or queue evidence;
- its retry, duplicate-delivery, and DLQ behavior; and
- the results for every portable test payload above.
