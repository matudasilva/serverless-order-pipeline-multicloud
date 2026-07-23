# Plan: core-pipeline

> Status: Approved and implemented.
> Depends on: `spec.md` of this feature (approved).

## Review summary

- **Approved**: ADR-3 (SQS DLQ + redrive policy, `maxReceiveCount = 5`).
- **Deviations from the original exercise**: DLQ added; SNS topic named
  `POC-Topic` (baseline left it unnamed); explicit CloudWatch Log Groups
  instead of Lambda's implicit ones (ADR-4); Lambda packaging via
  `archive_file` (ADR-5).
- **Key risks**: `dynamodb:ListStreams` can only be IAM-scoped to the
  stream ARN wildcard pattern, not an exact stream ARN (ADR-2) — still
  fully compliant with the no-`Resource: "*"` rule.

## Technical approach

All resources live in `envs/dev/`, split by concern (no `modules/` — see
"Terraform structure" below for justification):

- `providers.tf` — `required_version`, `hashicorp/aws` provider version
  and region, pinned to match `specs/tech-stack.md`.
- `variables.tf` — `notification_email`.
- `dynamodb.tf` — the `orders` table.
- `sqs.tf` — `POC-Queue`, its DLQ (ADR-3), redrive policy, and queue
  access policy.
- `iam.tf` — one role + one scoped policy per Lambda, plus explicit
  CloudWatch Log Groups (ADR-4).
- `lambda.tf` — both `aws_lambda_function` resources (packaged via
  `archive_file`, ADR-5), and both event source mappings.
- `sns.tf` — the topic and its email subscription.
- `outputs.tf` — queue URL/ARN, table name, topic ARN (useful for the
  `api-ingestion` feature and for manual verification after apply).

Python code lives in `src/lambdas/lambda_1/handler.py` and
`src/lambdas/lambda_2/handler.py`, each in its own directory so
`archive_file` can zip it independently. Both start from the baseline in
`docs/reference/original-lambdas.md` with the required improvements:
structured logging (`logging` module, JSON-ish key/value messages, no bare
`print`), boto3 client/resource created at module scope, configuration via
`os.environ` (`TABLE_NAME` for Lambda 1, `SNS_TOPIC_ARN` for Lambda 2),
and — for Lambda 1 — per-message error handling that returns
`batchItemFailures` instead of letting one bad message fail the whole
batch.

## Terraform resources

| Resource | File | Notes |
|---|---|---|
| `aws_dynamodb_table.orders` | `dynamodb.tf` | PK `orderID` (S), `PAY_PER_REQUEST` billing (ADR-1), stream `NEW_IMAGE`. |
| `aws_sqs_queue.poc_queue` | `sqs.tf` | Standard queue, named `POC-Queue`, redrive policy pointing at the DLQ (ADR-3). |
| `aws_sqs_queue.poc_queue_dlq` | `sqs.tf` | Dead-letter queue for `POC-Queue` (ADR-3). |
| `aws_sqs_queue_policy.poc_queue` | `sqs.tf` | Restrictive access policy; today only allows the account's Lambda ESM to consume — write access for API Gateway is added in `api-ingestion`, not here. |
| `aws_iam_role.lambda_1` / `aws_iam_role_policy.lambda_1` | `iam.tf` | Scoped to `POC-Queue` ARN (`ReceiveMessage`/`DeleteMessage`/`GetQueueAttributes`/`ChangeMessageVisibility`) + `orders` table ARN (`PutItem`) + own log group ARN. |
| `aws_iam_role.lambda_2` / `aws_iam_role_policy.lambda_2` | `iam.tf` | Scoped to the `orders` table's stream ARN pattern (`.../stream/*`, covers `GetRecords`/`GetShardIterator`/`DescribeStream`/`ListStreams`) + SNS topic ARN (`Publish`) + own log group ARN. |
| `aws_cloudwatch_log_group.lambda_1` / `.lambda_2` | `iam.tf` | Named exactly `/aws/lambda/<function_name>`; each Lambda function declares `depends_on` on its log group so Terraform creates it before Lambda can create one implicitly (ADR-4). |
| `data.archive_file.lambda_1` / `.lambda_2` | `lambda.tf` | Zips `src/lambdas/lambda_1/` and `src/lambdas/lambda_2/` at plan/apply time (ADR-5). |
| `aws_lambda_function.lambda_1` / `.lambda_2` | `lambda.tf` | Python 3.12, env vars per above. |
| `aws_lambda_event_source_mapping.sqs_to_lambda_1` | `lambda.tf` | `batch_size = 10`, `function_response_types = ["ReportBatchItemFailures"]`. |
| `aws_lambda_event_source_mapping.stream_to_lambda_2` | `lambda.tf` | `starting_position = "LATEST"`, `batch_size = 100`. |
| `aws_sns_topic.orders_notifications` | `sns.tf` | AWS resource `name = "POC-Topic"`, mirroring `POC-Queue`'s naming for traceability with the baseline (which left the topic unnamed). |
| `aws_sns_topic_subscription.email` | `sns.tf` | `protocol = "email"`, `endpoint = var.notification_email`. |

## Architecture decisions (ADRs)

### ADR-1: DynamoDB on-demand billing

- **Context**: the `orders` table's traffic is unpredictable PoC traffic
  (manual testing, no production load), and the constitution requires
  staying within the AWS free tier without capacity planning overhead.
- **Decision**: use `PAY_PER_REQUEST` billing mode instead of
  `PROVISIONED`.
- **Alternatives considered**: `PROVISIONED` with 1 RCU/WCU — cheaper at
  guaranteed steady low volume, but risks throttling on bursts and adds a
  capacity-planning concern this PoC doesn't need.
- **Consequences**: slightly higher per-request cost, which is
  irrelevant at PoC volume; no capacity tuning required.

### ADR-2: IAM least privilege scoping

- **Context**: non-negotiable rule #4 — no IAM policy may use
  `Resource: "*"`.
- **Decision**: every policy statement in `iam.tf` is scoped to the exact
  ARN of the resource it needs (queue, table, stream, topic, own log
  group). One documented exception: `dynamodb:ListStreams` (and the other
  stream-read actions, for consistency) is scoped to the table's stream
  ARN *pattern* (`arn:aws:dynamodb:us-east-1:<account_id>:table/orders/stream/*`)
  rather than a literal single stream ARN — IAM doesn't support scoping
  `ListStreams` any tighter, since the exact stream ARN (with its
  creation timestamp) doesn't exist until the table is created. This is
  still fully compliant with rule #4: it is not `Resource: "*"`.
- **Alternatives considered**: AWS managed policies (e.g.
  `AWSLambdaBasicExecutionRole`) — rejected, they grant `Resource: "*"`
  for CloudWatch Logs.
- **Consequences**: more verbose `iam.tf`, but every permission is
  auditable against a concrete resource or the narrowest pattern IAM
  allows.

### ADR-3: SQS dead-letter queue

- **Context**: the spec requires "correct retry handling" via
  `ReportBatchItemFailures`. Without a DLQ, a message whose processing
  fails indefinitely (e.g. malformed payload) cycles between the queue
  and Lambda 1 forever, never getting set aside.
- **Decision**: add `poc_queue_dlq` with a redrive policy
  (`maxReceiveCount = 5`) on `POC-Queue`. **Approved by the architect
  during design review.**
- **Alternatives considered**: no DLQ, matching the original exercise
  exactly — simpler, but leaves poison-pill messages retrying forever
  with no visibility, which undercuts the "correct retry handling"
  improvement the brief explicitly asked for.
- **Consequences**: one extra SQS queue (still free-tier eligible) and a
  redrive policy to maintain.

### ADR-4: Explicit CloudWatch Log Groups

- **Context**: without an explicit `aws_cloudwatch_log_group`, Lambda
  creates its log group implicitly on first invocation — a race that can
  leave Terraform and Lambda fighting over group creation, and forces IAM
  policies to reference a `/aws/lambda/<name>:*` pattern computed ahead of
  time or fall back to a broader wildcard.
- **Decision**: declare both log groups explicitly in `iam.tf`, named
  exactly `/aws/lambda/<function_name>` (matching what Lambda would use
  implicitly) with a short retention (14 days). Each
  `aws_lambda_function` declares `depends_on` on its log group, so
  Terraform always creates the group first and Lambda never gets the
  chance to create it implicitly.
- **Alternatives considered**: implicit log group creation — simpler, but
  weakens ADR-2's least-privilege guarantee and risks the creation race.
- **Consequences**: two more resources plus an explicit `depends_on`; log
  retention is bounded instead of indefinite (a minor hygiene
  improvement).

### ADR-5: Lambda packaging via `archive_file`

- **Context**: Lambda deployment packages need to be zipped from
  `src/lambdas/lambda_1/` and `src/lambdas/lambda_2/`.
- **Decision**: use the `archive_file` data source (part of the
  `hashicorp/archive` provider) so packaging happens inside
  `terraform plan`/`apply`, with no external build script or CI step.
- **Alternatives considered**: a `null_resource` + shell `zip` — works,
  but adds a second provider-less external dependency and is less
  portable across the architect's and CI's environments.
- **Consequences**: adds the `hashicorp/archive` provider (pinned
  alongside `hashicorp/aws` in `providers.tf`); no runtime dependencies
  beyond the Python standard library in either Lambda, so no dependency
  layer is needed yet.

## Variables and configuration

| Name | Type | Default | Sensitivity | Notes |
|---|---|---|---|---|
| `notification_email` | `string` | none (required) | `sensitive = true` | SNS email subscription endpoint. Supplied via a local, gitignored `terraform.tfvars` or `-var` at apply time — never committed. |

Lambda environment variables (set by Terraform, not variables themselves):

| Lambda | Env var | Value |
|---|---|---|
| Lambda 1 | `TABLE_NAME` | `aws_dynamodb_table.orders.name` |
| Lambda 2 | `SNS_TOPIC_ARN` | `aws_sns_topic.orders_notifications.arn` |

## Validation

- `terraform fmt -check` and `terraform validate` in `envs/dev/`.
- `terraform plan -var="notification_email=test@example.com"` — a
  placeholder value is fine for `plan` since the goal is to prove the
  configuration is internally consistent, not to apply it.
- Manual review of the acceptance criteria in `spec.md` against the
  generated plan output (resource attributes, IAM statements).
- No `apply` — deferred to the architect per the constitution.
- Note for when the architect applies manually: the SNS email
  subscription stays `PendingConfirmation` until the recipient clicks the
  confirmation link AWS emails them — Terraform can't complete this step,
  so a pending subscription right after `apply` is expected, not a
  failure.

## Risks / trade-offs

- On-demand DynamoDB billing scales with usage; irrelevant at PoC volume
  but worth flagging if this were ever repurposed beyond a portfolio PoC.
- ADR-3's DLQ adds a small amount of extra surface for a benefit
  (visibility into poison messages) that's easy to underrate in a PoC.
- Packaging via `archive_file` (ADR-5) works cleanly today because both
  Lambdas have zero third-party dependencies; if a future dependency is
  needed, this approach would need revisiting (e.g. Lambda layers).
