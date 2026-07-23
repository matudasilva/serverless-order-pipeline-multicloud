**Authorship:** Codex (GPT-5) through reverse engineering of the repository and validated by Matías.
**Date:** 2026-07-23
**Version:** v1.0

# Technical Stack — Serverless Order Pipeline Multicloud

## Stack

- Terraform `>= 1.9`; the CI workflow pins Terraform `1.9.8`.
- AWS baseline: `hashicorp/aws ~> 5.0` and `hashicorp/archive ~> 2.0` providers in `us-east-1`.
- Python 3.12 for the AWS Lambdas, packaged with `archive_file` from `providers/aws/src/lambdas/`.
- AWS baseline services: API Gateway, SQS with DLQ, Lambda, DynamoDB with Streams, SNS, CloudWatch Logs, and least-privilege IAM.
- Git and GitHub; GitHub Actions runs Terraform formatting and validation without a backend or credentials.
- AI Together Framework V3 with English narrative artifacts, a `hybrid` policy, Notion operational memory, and a limit of two active ORQs.

## Constraints

- Each provider remains isolated under `providers/<cloud>/`; Terraform is the shared IaC tool.
- Multicloud equivalence is defined by architectural responsibility, not by service name.
- Automatable validations do not modify infrastructure; `apply` and `destroy` are manual architect operations.
- Sensitive configuration stays out of Git: `terraform.tfvars`, Terraform state, caches, builds, and credentials are ignored.
- GCP and Azure must respect free-tier availability, controlled costs, and documented teardown before resources are created.

## Technical Invariants

- The shared pipeline keeps HTTP ingress, queue or messaging, NoSQL persistence, a post-persistence event, and notification.
- Existing AWS infrastructure is not refactored without an explicit ORQ: the baseline retains its functional behavior.
- IAM follows least privilege; wildcard permissions are not introduced unless a documented provider requirement makes them necessary.
- Lambdas and Terraform must continue to validate from their provider-specific paths.
- Shared contracts do not depend on AWS, GCP, or Azure implementation details.
