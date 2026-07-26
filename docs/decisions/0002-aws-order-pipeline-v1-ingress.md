# ADR 0002: AWS Order Pipeline v1 Ingress Conformance

## Status

Accepted: option C, explicit partial conformance. This ADR does not change AWS
Terraform, Lambda code, request handling, persistence, or deployment.

## Context

AWS currently uses a direct API Gateway REST API to SQS integration. It avoids
an ingress Lambda, accepts the raw request body, and maps successful SQS sends
to `200` with `status: queued`. Order Pipeline v1 instead requires portable
input validation, `202 Accepted`, and `400` errors.

API Gateway REST API request validators can validate a body against a model and
return `400` before the integration. Models use JSON Schema draft 4; validation
requires a matching content type (or `$default`). [AWS request validation](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-method-request-validation.html)
and [data-model documentation](https://docs.aws.amazon.com/apigateway/latest/developerguide/models-mappings-models.html)
support required fields, string type/length, integer type, and numeric minimum.
The current repository has not proved an API Gateway-only implementation for
every v1 rule, response shape, malformed JSON path, and content-type edge case.

## Options

### A. API Gateway validation with direct SQS integration

Add request models, a request validator, mapping templates, and explicit
`202`, `400`, and `5xx` responses while keeping API Gateway to SQS direct.

- Advantages: preserves the native ingress path, its low operational surface,
  and the existing scoped `sqs:SendMessage` role.
- Disadvantages: JSON Schema draft 4 and gateway response/mapping behavior
  require a provider-specific proof for trim semantics, malformed JSON, and the
  exact portable error body. Validation coverage may remain incomplete.
- Security and operations: no new runtime identity or code deployment; model
  and gateway-response changes still need careful live evidence.
- Cost: no Lambda invocation or additional log group.

### B. Lambda ingress

Add an ingress Lambda that validates in Python, returns the portable response,
and sends accepted orders to SQS.

- Advantages: exact portable validation and response behavior live in code and
  can share tests with other providers.
- Disadvantages: adds latency, invocation cost, deployment/package ownership,
  IAM permissions, logs, failure modes, and a new component in the request
  path. It weakens the simplicity of the existing native integration.
- Security and operations: needs a narrowly scoped `sqs:SendMessage` role and
  operational support for another Lambda.

### C. Explicit partial conformance

Keep the direct integration unchanged and document AWS as a historical baseline
that is not Order Pipeline v1-conformant.

- Advantages: preserves validated historical architecture and avoids unproven
  gateway behavior or a new function.
- Disadvantages: AWS cannot pass the portable v1 HTTP runner and comparison
  remains intentionally asymmetric.
- Security, operations, and cost: no new permissions, components, or cost.

## Recommendation

Choose option C now. It is the only option fully supported by current evidence
and preserves the documented architectural decision. If v1 conformance becomes
required, prototype and prove option A with all portable payloads before
considering option B. Do not add an ingress Lambda without a separate approved
decision.

## Decision

The architect selected option C. AWS remains explicitly non-conformant to Order
Pipeline v1, retains `orderID` and `200`, and preserves direct API Gateway to
SQS ingress. Any future move to option A or B requires a new approved decision
and complete evidence for the portable contract.
