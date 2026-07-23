# Spec: api-ingestion

> Status: Approved and implemented.

## Review summary

- **Approved**: `/orders` as the resource path (root resource rejected —
  see plan.md); JSON response mapping for `200`; explicit `400`/`500`
  error mapping; access logging on the `dev` stage.
- **Deviations from the baseline/original exercise**: the API Gateway →
  SQS IAM role is scoped to `sqs:SendMessage` on `POC-Queue`'s exact ARN
  instead of a broader grant (rule #4); the `200` response returns JSON
  instead of raw SQS XML (ADR-8); errors are explicitly mapped instead of
  silently returning `200` with an XML error body.
- **Key risks**: none blocking. This feature only adds resources; it does
  not modify `POC-Queue` or its existing consumers from `core-pipeline`.

## What

A REST API (`POC-API`) that accepts `POST /orders` requests and forwards
the request body directly to the `POC-Queue` SQS queue created in
`core-pipeline`, via a native API Gateway → SQS service integration (no
Lambda in the request path), returning a JSON response and mapping SQS
errors to proper HTTP status codes.

## Why

This is the public entry point for Exercise 1's PoC — closing the loop
`Client → API Gateway → SQS → ...` described in the roadmap. It plugs
into the queue `core-pipeline` already created; no changes to
`core-pipeline`'s resources are needed.

## Scope

- In scope:
  - REST API `POC-API` (`aws_api_gateway_rest_api`).
  - A child resource `/orders` under the API's root, with a `POST` method,
    `authorization = "NONE"` (no auth, matching the constitution's
    explicit out-of-scope decision on API authentication).
  - AWS Service integration to SQS: path override to
    `{account_id}/POC-Queue`, request template
    `Action=SendMessage&MessageBody=$input.body`, integration request
    header `Content-Type: application/x-www-form-urlencoded`.
  - Method response / integration response for `200`, mapping the raw SQS
    XML response to JSON (ADR-8).
  - Method response / integration response for `400` and `500`, mapping
    SQS error responses to proper HTTP status codes instead of a silent
    `200`.
  - IAM role for API Gateway, scoped to `sqs:SendMessage` on `POC-Queue`'s
    ARN only.
  - `aws_api_gateway_deployment` + `aws_api_gateway_stage` named `dev`,
    with automatic redeployment when the API configuration changes, and
    access logging to an explicit CloudWatch Log Group.
  - `aws_api_gateway_account` (account-scoped, not API-scoped) setting the
    IAM role API Gateway uses to write access logs to CloudWatch.
- Out of scope:
  - Any change to `POC-Queue`, `core-pipeline`'s Lambdas, or their IAM
    roles.
  - Request validation, API keys, usage plans, or throttling — not
    required by the original exercise.
  - Authentication/authorization (explicitly out of scope per
    `specs/roadmap.md`).
  - Custom domain names or CORS configuration.

## Functional requirements

1. A `POST` request to `/orders` on the `dev` stage's invoke URL, with an
   arbitrary text/JSON body, results in exactly one message sent to
   `POC-Queue` whose body equals the request body.
2. The request never reaches a Lambda function — API Gateway talks to SQS
   directly via the AWS Service integration.
3. A successful send returns `200` with a JSON body containing the SQS
   `MessageId` and a `status` field — not raw SQS XML.
4. An SQS client-error response (e.g. malformed `SendMessage` request)
   returns HTTP `400`; an SQS server-error response returns HTTP `500` —
   neither is silently returned as `200`.
5. The IAM role assumed by API Gateway for this integration can only
   `sqs:SendMessage` to `POC-Queue` — nothing else.
6. The stage is named `dev`, its invoke URL is exposed as a Terraform
   output, and every request to it is recorded in a CloudWatch access log.

## Acceptance criteria (verifiable)

- [ ] `terraform fmt -check` and `terraform validate` report no issues in
      `envs/dev/`.
- [ ] `terraform plan` runs with no errors (using the same placeholder
      `notification_email` as `core-pipeline`, via
      `AWS_PROFILE=serverless-pipeline`).
- [ ] The `aws_api_gateway_rest_api` resource is named `POC-API`.
- [ ] A `aws_api_gateway_resource` exists for path part `orders` under the
      API's root resource, and the `POST` method is attached to it (not to
      the root resource).
- [ ] The `POST` method's `authorization` is `"NONE"` and it has no API
      key requirement.
- [ ] The `aws_api_gateway_integration` resource has `type = "AWS"`,
      `integration_http_method = "POST"`, and a `uri` that path-overrides
      to this account's ID and `POC-Queue`'s name (not a hardcoded
      account ID).
- [ ] The integration's `request_templates` for `application/json` is
      exactly `Action=SendMessage&MessageBody=$input.body`.
- [ ] The integration's `request_parameters` sets
      `integration.request.header.Content-Type` to
      `'application/x-www-form-urlencoded'`.
- [ ] The `200` integration response's template transforms the SQS XML
      body into JSON containing `messageId` and `status`, and its
      `selection_pattern` no longer acts as a catch-all now that `400`/
      `500` are explicitly mapped.
- [ ] `400` and `500` method/integration responses exist, with
      `selection_pattern`s matching SQS's `4XX`/`5XX` error responses
      respectively.
- [ ] The IAM role/policy granting API Gateway access to SQS scopes
      `sqs:SendMessage` to `POC-Queue`'s exact ARN — no `Resource: "*"`.
- [ ] A `dev` stage exists, backed by a deployment that is not manually
      recreated on unrelated changes (redeployment is triggered only when
      the API's method/integration configuration changes).
- [ ] The `dev` stage's `access_log_settings` points at an explicit
      `aws_cloudwatch_log_group` (not an implicitly created one), with a
      bounded retention period.
- [ ] An `aws_api_gateway_account` resource sets the account-level
      CloudWatch role API Gateway uses for access logging.
- [ ] No resource or IAM policy from `core-pipeline` is modified by this
      feature's `terraform plan` output (`0 to change` for
      `core-pipeline`'s resources).

## Open questions

None.
