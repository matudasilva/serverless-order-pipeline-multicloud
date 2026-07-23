# AWS Pipeline Baseline

AWS is the functional reference implementation for the multicloud comparison. Its logical flow is
`POST /orders → API Gateway → SQS → Lambda 1 → DynamoDB → DynamoDB Streams → Lambda 2 → SNS → email`.

## Preserved behavior

- API Gateway sends request bodies directly to `POC-Queue`; no Lambda is in the HTTP path.
- Lambda 1 persists orders to DynamoDB; the table uses `orderID` as its string key and emits
  `NEW_IMAGE` stream records.
- Lambda 2 consumes stream inserts and publishes notifications to SNS. SQS failures use a DLQ and
  partial batch failure reporting.
- Terraform and Lambda validation are provider-scoped under `providers/aws/`; agents never apply
  or destroy infrastructure.

## Historical evidence

The original AWS repository records a prior live end-to-end verification and subsequent teardown.
It is evidence of the baseline, not a claim that resources are currently deployed. This repository
retains only the synthesized baseline and decision documentation needed for active multicloud work.
