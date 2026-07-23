# Plan: api-ingestion

> Status: Approved and implemented.
> Depends on: `spec.md` of this feature (approved); `core-pipeline`'s
> `POC-Queue` (exists in `envs/dev/sqs.tf`; not yet deployed to AWS).

## Review summary

- **Approved**: `/orders` resource path (root resource rejected); JSON
  response mapping (ADR-8); explicit `400`/`500` error mapping; access
  logging on the `dev` stage (ADR-9).
- **Deviations from the baseline/original exercise**: API Gateway's IAM
  role scoped to `POC-Queue`'s exact ARN (rule #4); `/orders` as a
  semantic resource path instead of the root (`/`) the original console
  exercise uses — root is a console-demo shortcut, not appropriate for
  IaC portfolio work; JSON response instead of raw SQS XML (ADR-8).
- **Key risks**: none — additive only, no `core-pipeline` resource is
  touched.
- **Post-implementation fix**: `apply` initially failed on
  `aws_api_gateway_account` — AWS rejects the account-level CloudWatch
  role if it's scoped below `Resource: "*"` for CloudWatch Logs actions.
  ADR-10 documents this as the project's sole forced exception to the
  no-`Resource: "*"` rule.

## Technical approach

One new file, `envs/dev/api_gateway.tf`, added to the same `envs/dev/`
root module as `core-pipeline` (no `modules/` — this is a handful of
resources with no reuse case). It references `core-pipeline`'s
`aws_sqs_queue.poc_queue` and the existing `data.aws_caller_identity.current`
directly, since they're in the same root module.

Region is hardcoded to `us-east-1` in the integration URI, consistent with
`providers.tf`'s existing hardcoded region (single-region scope).

Local `terraform plan` runs use the read-only `serverless-pipeline` AWS CLI
profile: `AWS_PROFILE=serverless-pipeline terraform plan -var="notification_email=test@example.com"`.

## Files and responsibilities

- `envs/dev/api_gateway.tf` — `aws_api_gateway_rest_api.poc_api`; the
  `aws_api_gateway_resource` for `/orders` and its `POST` method
  (`authorization = "NONE"`); the `AWS`-type integration to SQS (path
  override, request template, `Content-Type` header); `200`/`400`/`500`
  method and integration responses (ADR-8); the
  `aws_iam_role`/`aws_iam_role_policy` API Gateway assumes for the SQS
  integration (scoped to `POC-Queue`'s ARN, `sqs:SendMessage` only); the
  `aws_api_gateway_deployment` (redeploy `triggers` hash the method +
  integration + IAM policy) and the `dev` `aws_api_gateway_stage` with
  access logging (ADR-9); the account-scoped `aws_api_gateway_account`
  resource, commented to clarify it configures the whole AWS account's API
  Gateway CloudWatch role, not just `POC-API`.
- `envs/dev/outputs.tf` — one new output, `api_invoke_url` (the `dev`
  stage's invoke URL), appended to the file `core-pipeline` created.

## Architecture decisions (ADRs)

### ADR-6: API Gateway → SQS IAM scoping

- **Context**: non-negotiable rule #4 — no IAM policy may use
  `Resource: "*"`.
- **Decision**: the role API Gateway assumes for the SQS integration
  grants only `sqs:SendMessage` on `POC-Queue`'s exact ARN.
- **Alternatives considered**: a broader or AWS-managed grant — rejected,
  violates rule #4 or grants more than `SendMessage`.
- **Consequences**: one small IAM role/policy pair dedicated to this
  integration; no impact on `core-pipeline`'s existing roles.

### ADR-7: Redeployment trigger

- **Context**: `aws_api_gateway_deployment` doesn't automatically detect
  changes to the method/integration it fronts; without a trigger, `apply`
  can silently leave a stale deployment live.
- **Decision**: set `triggers = { redeployment = sha1(jsonencode([...])) }`
  over the method, integration, and IAM policy resources, with
  `lifecycle { create_before_destroy = true }` on the deployment.
- **Alternatives considered**: manual redeployment via CLI after every
  `apply` — rejected, error-prone.
- **Consequences**: slightly more complex `api_gateway.tf`, but `apply`
  alone keeps the `dev` stage in sync with the configuration.

### ADR-8: JSON response mapping and explicit error handling

- **Context**: the AWS Service (non-proxy) integration returns SQS's raw
  XML response by default. Returning XML to a client expecting JSON is
  misleading and hard to defend in an architecture review — an explicit
  improvement over the original exercise, which leaves this unmapped.
- **Decision**: the `200` integration response's template parses the SQS
  XML with `$util.parseXml(body)` and emits
  `{"messageId": "...", "status": "queued"}`. Because the `200` response
  is now explicitly mapped, it can no longer act as a catch-all — SQS
  errors would otherwise return `200` with an XML error body, which is
  actively incorrect. `400` and `500` integration responses are added
  with `selection_pattern`s matching SQS's `4XX`/`5XX` error responses,
  so client and server errors surface as real HTTP error codes.
- **Alternatives considered**: leave the raw XML passthrough (original
  exercise's behavior) — rejected, misleading to any JSON-expecting
  client and indefensible in review.
- **Consequences**: three response mappings instead of one catch-all;
  once any response is explicitly mapped, every reachable SQS outcome
  must be mapped too, or it falls through unhandled.

### ADR-9: Access logging on the `dev` stage

- **Context**: the stage has no request visibility by default; a PoC
  meant to be inspected in a portfolio review benefits from being able to
  show what hit the API.
- **Decision**: add `access_log_settings` on `aws_api_gateway_stage.dev`,
  pointing at an explicit `aws_cloudwatch_log_group` (same pattern as
  `core-pipeline`'s ADR-4: explicit group, bounded retention, no implicit
  creation). Log format: a JSON line with `requestId`, `ip`, `requestTime`,
  `httpMethod`, `resourcePath`, `status`, and `responseLength` — enough to
  audit traffic without the verbosity of the full `$context` object.
  Because this requires an account-level CloudWatch role, an
  `aws_api_gateway_account` resource is added — this setting is
  account-scoped, not specific to `POC-API`, so applying it here affects
  API Gateway access logging for the whole AWS account. Confirmed via
  `aws apigateway get-account` that no `cloudwatchRoleArn` is currently
  set for this account, so there's no existing configuration to collide
  with or import. That role's policy started as a custom document scoped
  to this feature's access log group ARN, rather than AWS's suggested
  `AmazonAPIGatewayPushToCloudWatchLogs` managed policy — but AWS itself
  rejects that narrower scoping at `apply` time; see ADR-10 for what the
  policy actually had to become and why.
- **Alternatives considered**: no access logging — rejected, loses the
  ability to demonstrate/debug traffic for a portfolio PoC.
- **Consequences**: one more explicit log group (bounded retention, same
  hygiene as ADR-4) and one account-scoped resource whose effect isn't
  limited to this feature's API.

### ADR-10: CloudWatch role for `aws_api_gateway_account` requires `Resource: "*"`

- **Context**: `aws_api_gateway_account` is an account-scoped setting.
  AWS validates the associated IAM role at configuration time against a
  minimum set of CloudWatch Logs actions, and rejects any role that
  scopes those actions below `Resource: "*"` — the service needs to
  create and write log groups dynamically for any API in the account,
  not just the one this project manages.
- **Decision**: the `api_gateway_cloudwatch` role's policy uses
  `Resource: "*"` for CloudWatch Logs actions
  (`CreateLogGroup`/`CreateLogStream`/`DescribeLogGroups`/
  `DescribeLogStreams`/`PutLogEvents`/`GetLogEvents`/`FilterLogEvents`)
  only. This is the sole exception to `core-pipeline`'s ADR-2 in this
  project, forced by an AWS structural constraint, not by choice. Every
  other IAM policy in this project remains scoped to exact ARNs. The
  feature's own access-log group
  (`aws_cloudwatch_log_group.api_gateway_access_logs`) is unaffected —
  it keeps its explicit declaration and bounded retention regardless of
  what this account-level role can reach.
- **Alternatives considered**: scoping to a log-group prefix pattern
  (`arn:aws:logs:us-east-1:<account>:log-group:/aws/apigateway/*`) —
  rejected because AWS's own `UpdateAccount` validation rejects it,
  confirmed by a real `terraform apply` failure
  (`BadRequestException: The role ARN does not have required
  permissions configured.`) against the log-group-scoped policy ADR-9
  originally shipped.
- **Consequences**: this account-scoped role can now write to any log
  group in the account, not just this project's — an unavoidable
  consequence of how `aws_api_gateway_account` works, not a widening of
  scope this project chose.

## Variables and configuration

None new — this feature reuses `core-pipeline`'s existing
`aws_sqs_queue.poc_queue` and `data.aws_caller_identity.current`, no new
Terraform variables.

## Validation

- `terraform fmt -check` and `terraform validate` in `envs/dev/` (run
  against the full stack, `core-pipeline` + `api-ingestion` together).
- `AWS_PROFILE=serverless-pipeline terraform plan -var="notification_email=test@example.com"`
  — must show additions only for this feature's resources (plus the
  account-scoped `aws_api_gateway_account` change noted in ADR-9), `0 to
  change` for every `core-pipeline` resource.
- Manual review of the acceptance criteria in `spec.md` against the
  generated plan output.
- No `apply` — deferred to the architect per the constitution.
- No manual-apply caveats specific to this feature (unlike
  `core-pipeline`'s SNS subscription, nothing here needs post-apply human
  action).

## Risks / trade-offs

- `aws_api_gateway_account` is account-scoped: if another API in this AWS
  account later sets its own CloudWatch role via the same resource, the
  two configurations will conflict at `apply` time. Not a risk today
  (confirmed no existing `cloudwatchRoleArn`), but worth knowing if this
  account is ever reused beyond this portfolio.
- The three-way response mapping (`200`/`400`/`500`) only covers the
  patterns SQS is known to return; an SQS error outside those patterns
  would fall through unhandled by API Gateway's default behavior.
