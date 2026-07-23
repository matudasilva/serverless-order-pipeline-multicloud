# Spec: core-pipeline

> Status: Approved and implemented.

## Review summary

- **Approved**: ADR-3 (SQS dead-letter queue for `POC-Queue`,
  `maxReceiveCount = 5` redrive policy).
- **Deviations from the original exercise**: DLQ + redrive policy added
  (baseline has none); per-message batch failure handling instead of
  failing the whole batch; SNS topic named `POC-Topic` for naming
  consistency with `POC-Queue` (baseline left it unnamed).
- **Key risks**: none blocking — `dynamodb:ListStreams` can only be IAM-
  scoped to the stream ARN *pattern* (`.../stream/*`), not a single
  stream ARN; still fully compliant with the no-`Resource: "*"` rule.

## What

The core order-processing pipeline: an SQS queue receives order messages,
Lambda 1 persists each message to a DynamoDB table, DynamoDB Streams
captures every insert, and Lambda 2 publishes a notification for it to an
SNS topic with an email subscription.

## Why

This is the heart of Exercise 1's PoC — decoupled ingestion/processing via
SQS, durable storage in DynamoDB, and event-driven notification via
Streams + SNS. It's also the foundation the `api-ingestion` feature
(Phase 3) plugs into: that feature only adds a public HTTP entry point in
front of the `POC-Queue` created here.

## Scope

- In scope:
  - DynamoDB table `orders` (PK `orderID`, string) with Streams enabled
    (`NEW_IMAGE`).
  - SQS standard queue `POC-Queue` with a restrictive access policy.
  - Lambda 1 (Python 3.12): SQS → DynamoDB, least-privilege role, boto3
    client initialized outside the handler, table name via environment
    variable, structured logging, correct batch-item-failure reporting on
    the SQS event source mapping.
  - Lambda 2 (Python 3.12): DynamoDB Streams → SNS, least-privilege role,
    boto3 client initialized outside the handler, topic ARN via
    environment variable, structured logging.
  - SNS topic + one email subscription (email address supplied via a
    Terraform variable, no default).
  - Event source mappings: SQS → Lambda 1, DynamoDB Stream → Lambda 2.
  - IAM roles/policies scoped to exact resource ARNs (no `Resource: "*"`).
- Out of scope:
  - API Gateway / public HTTP ingestion — covered by `api-ingestion`
    (Phase 3).
  - Multi-environment or multi-region deployment.
  - Alarms, dashboards, or observability beyond structured Lambda logging.
  - A dead-letter queue is *proposed*, not assumed, in `plan.md` (see
    ADR-3) — it needs explicit architect approval since it's not called
    out in the original exercise description.

## Functional requirements

1. Any message sent to `POC-Queue` is persisted as an item in the `orders`
   table with a generated `orderID` and the message body as `order`.
2. A failure processing one SQS message in a batch does not cause the
   whole batch to be retried — only the failed message(s) are reported
   back via `ReportBatchItemFailures` and retried individually.
3. Every `INSERT` event on the `orders` table's stream triggers Lambda 2,
   which publishes the new item to the SNS topic.
4. The SNS topic has exactly one email subscription, whose address is
   supplied via a Terraform variable at apply time (never hardcoded).
5. Neither Lambda's IAM role can access AWS resources beyond what it
   needs to do its job.

## Acceptance criteria (verifiable)

- [ ] `terraform fmt -check` and `terraform validate` report no issues in
      `envs/dev/`.
- [ ] `terraform plan` runs with no errors (using a placeholder value for
      `notification_email`).
- [ ] The `orders` DynamoDB table resource declares `hash_key = "orderID"`
      (type `S`), `stream_enabled = true`, and
      `stream_view_type = "NEW_IMAGE"`.
- [ ] The SQS queue resource is a standard queue (no FIFO suffix/config)
      named `POC-Queue`, with a resource policy that does not grant
      unconditioned access to `Principal = "*"`.
- [ ] Lambda 1's IAM policy grants only `sqs:ReceiveMessage`,
      `sqs:DeleteMessage`, `sqs:GetQueueAttributes`, and
      `sqs:ChangeMessageVisibility` (required by the SQS event source
      mapping to manage visibility during partial-batch retries) scoped
      to the `POC-Queue` ARN, `dynamodb:PutItem` scoped to the `orders`
      table ARN, and log permissions scoped to its own log group ARN —
      nothing broader.
- [ ] Lambda 2's IAM policy grants only `dynamodb:GetRecords`,
      `dynamodb:GetShardIterator`, `dynamodb:DescribeStream`, and
      `dynamodb:ListStreams` scoped to the `orders` table's stream ARN
      *pattern* (`arn:aws:dynamodb:us-east-1:<account_id>:table/orders/stream/*`
      — the finest granularity IAM supports for `ListStreams`, since the
      exact stream ARN doesn't exist until the table is created),
      `sns:Publish` scoped to the topic ARN, and log permissions scoped to
      its own log group ARN — nothing broader.
- [ ] No IAM policy statement introduced by this feature uses
      `Resource: "*"`.
- [ ] Each Lambda's CloudWatch Log Group is named exactly
      `/aws/lambda/<function_name>` and is created by Terraform before the
      corresponding Lambda function (no implicit log-group-creation
      race).
- [ ] The SNS topic's AWS resource name is `POC-Topic`.
- [ ] Lambda 1 and Lambda 2 source code has no hardcoded table name or
      topic ARN (both come from environment variables), and both
      initialize their boto3 client/resource at module scope, not inside
      `lambda_handler`.
- [ ] The SQS → Lambda 1 event source mapping sets
      `function_response_types = ["ReportBatchItemFailures"]`.
- [ ] `notification_email` is declared as a Terraform variable with no
      default, so `apply` fails fast if it isn't supplied.

## Open questions

None — see `plan.md`'s ADRs for the design decisions made while drafting
this feature; they're presented there for approval rather than assumed
here.
