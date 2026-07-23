# Tasks: core-pipeline

> Status: Approved and implemented.
> Depends on: `plan.md` of this feature (approved).
> Each task should result in an atomic commit (Conventional Commits, in
> English).

- [ ] T1 — Scaffold `envs/dev/providers.tf`
  - **Definition of done**: `required_version` and the `hashicorp/aws` +
    `hashicorp/archive` provider version constraints match
    `specs/tech-stack.md`; `region = "us-east-1"` set on the AWS provider
    block (hardcoded, not a variable — single-region scope per
    constitution).
- [ ] T2 — Add `envs/dev/variables.tf`
  - **Definition of done**: declares `notification_email` (`string`, no
    default, `sensitive = true`). `.gitignore` updated to exclude
    `*.tfvars` (except a committed `terraform.tfvars.example` placeholder)
    so the real email is never committed.
- [ ] T3 — Add `envs/dev/dynamodb.tf`
  - **Definition of done**: `aws_dynamodb_table.orders` with
    `billing_mode = "PAY_PER_REQUEST"`, `hash_key = "orderID"` (type `S`),
    `stream_enabled = true`, `stream_view_type = "NEW_IMAGE"`.
- [ ] T4 — Add `envs/dev/sqs.tf`
  - **Definition of done**: `aws_sqs_queue.poc_queue` (`POC-Queue`,
    standard queue), `aws_sqs_queue.poc_queue_dlq`, a redrive policy
    (`maxReceiveCount = 5`) linking them, and `aws_sqs_queue_policy` with
    no unconditioned `Principal = "*"` grant.
- [ ] T5 — Write `src/lambdas/lambda_1/handler.py`
  - **Definition of done**: SQS → DynamoDB; boto3 resource created at
    module scope; table name read from `os.environ["TABLE_NAME"]`;
    structured logging (no bare `print`); per-record `try/except` that
    collects failed message IDs and returns
    `{"batchItemFailures": [...]}` instead of raising on the first bad
    record.
- [ ] T6 — Write `src/lambdas/lambda_2/handler.py`
  - **Definition of done**: DynamoDB Streams → SNS; boto3 client created
    at module scope; topic ARN read from
    `os.environ["SNS_TOPIC_ARN"]`; structured logging; only processes
    `INSERT` events, consistent with the baseline.
- [ ] T7 — Add `envs/dev/iam.tf`
  - **Definition of done**: `aws_cloudwatch_log_group.lambda_1` /
    `.lambda_2`, named exactly `/aws/lambda/<function_name>`;
    `aws_iam_role` + `aws_iam_role_policy` per Lambda, each scoped exactly
    to the ARNs/patterns in `plan.md`'s resource table (Lambda 1 includes
    `sqs:ChangeMessageVisibility` on `POC-Queue`; Lambda 2's stream-read
    actions, including `dynamodb:ListStreams`, are scoped to the stream
    ARN pattern `.../stream/*`) — no `Resource: "*"` anywhere, no AWS
    managed execution-role policies.
- [ ] T8 — Add `envs/dev/lambda.tf`
  - **Definition of done**: `data.archive_file` for each Lambda directory;
    `aws_lambda_function.lambda_1` / `.lambda_2` (Python 3.12, env vars
    wired per `plan.md`, each with `depends_on` on its own
    `aws_cloudwatch_log_group` from T7 to prevent the implicit
    log-group-creation race); `aws_lambda_event_source_mapping` for SQS →
    Lambda 1 (`function_response_types = ["ReportBatchItemFailures"]`) and
    for the DynamoDB stream → Lambda 2 (`starting_position = "LATEST"`).
- [ ] T9 — Add `envs/dev/sns.tf`
  - **Definition of done**: `aws_sns_topic.orders_notifications`
    (`name = "POC-Topic"`) and `aws_sns_topic_subscription.email`
    (`protocol = "email"`, `endpoint = var.notification_email`).
- [ ] T10 — Add `envs/dev/outputs.tf`
  - **Definition of done**: outputs for the queue URL/ARN, table name,
    and topic ARN (consumed later by `api-ingestion`, useful for manual
    verification now).

## Feature final validation

- [ ] `terraform fmt -check` reports no pending changes.
- [ ] `terraform validate` reports no errors.
- [ ] `terraform plan -var="notification_email=test@example.com"` runs
      without errors and the result is summarized against `spec.md`'s
      acceptance criteria.
- [ ] Results summary presented to the architect for approval (STOP —
      wait for explicit OK before the `api-ingestion` feature).
