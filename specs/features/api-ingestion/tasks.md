# Tasks: api-ingestion

> Status: Approved and implemented.
> Depends on: `plan.md` of this feature (approved).
> Local `plan`/`validate` runs use `AWS_PROFILE=serverless-pipeline`.
> Each task should result in an atomic commit (Conventional Commits, in
> English).

- [ ] T1 — Add the REST API, `/orders` resource, and its `POST` method to `envs/dev/api_gateway.tf`
  - **Definition of done**: `aws_api_gateway_rest_api.poc_api` (name
    `POC-API`); `aws_api_gateway_resource.orders` (`path_part = "orders"`,
    parent = the API's root resource id); `aws_api_gateway_method.post_orders`
    attached to `aws_api_gateway_resource.orders` (not the root resource),
    `http_method = "POST"`, `authorization = "NONE"`.
- [ ] T2 — Add the SQS integration, IAM role, and response mappings to `envs/dev/api_gateway.tf`
  - **Definition of done**: `aws_iam_role`/`aws_iam_role_policy` for API
    Gateway scoped to `sqs:SendMessage` on `aws_sqs_queue.poc_queue.arn`
    only (ADR-6); `aws_api_gateway_integration` (`type = "AWS"`,
    `integration_http_method = "POST"`, `uri` path-overriding to
    `data.aws_caller_identity.current.account_id` and
    `aws_sqs_queue.poc_queue.name`, `credentials` set to the new role,
    `request_parameters` setting the `Content-Type` header, and
    `request_templates` with the `Action=SendMessage&MessageBody=$input.body`
    mapping); `aws_api_gateway_method_response` +
    `aws_api_gateway_integration_response` for `200` (JSON template per
    ADR-8, non-catch-all `selection_pattern`), `400` (SQS `4XX`
    `selection_pattern`), and `500` (SQS `5XX` `selection_pattern`).
- [ ] T3 — Add deployment, `dev` stage with access logging, and the account resource to `envs/dev/api_gateway.tf`
  - **Definition of done**: `aws_api_gateway_deployment` with a `triggers`
    hash over the method/integration/IAM policy (ADR-7) and
    `lifecycle { create_before_destroy = true }`; explicit
    `aws_cloudwatch_log_group` for access logs (bounded retention, no
    implicit creation, same pattern as `core-pipeline` ADR-4);
    `aws_api_gateway_stage` named `dev`, referencing that deployment, with
    `access_log_settings` pointing at the new log group and the JSON
    format documented in ADR-9; `aws_api_gateway_account` resource setting
    the account-level CloudWatch role, with a comment noting it is
    account-scoped, not `POC-API`-scoped.
- [ ] T4 — Add `api_invoke_url` output
  - **Definition of done**: new output in `envs/dev/outputs.tf` exposing
    the `dev` stage's `invoke_url` (base path; `/orders` appended by the
    caller).

## Feature final validation

- [ ] `terraform fmt -check` reports no pending changes.
- [ ] `terraform validate` reports no errors.
- [ ] `AWS_PROFILE=serverless-pipeline terraform plan -var="notification_email=test@example.com"`
      runs without errors, shows additions only for this feature's
      resources (plus the account-scoped `aws_api_gateway_account` change
      per ADR-9), and `0 to change` for every `core-pipeline` resource;
      the result is summarized against `spec.md`'s acceptance criteria.
- [ ] Results summary presented to the architect for approval (STOP —
      wait for explicit OK before the `diagrams` feature).
