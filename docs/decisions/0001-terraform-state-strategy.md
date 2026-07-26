# ADR 0001: Provider-Isolated Terraform State Strategy

## Status

Accepted for the current personal-project operating model. This ADR does not
create, migrate, or configure a remote backend.

## Context

AWS has one Terraform root, GCP has independent bootstrap and workload roots,
and Azure has one Terraform root. None declares a backend block. Terraform
therefore uses local state by default; GCP documentation also states this
explicitly. State, plans, `terraform.tfvars`, and Terraform caches are ignored
by Git.

The project currently has one operator and uses ephemeral, manually approved
deployments. Remote state would add bootstrap resources, credentials, access
control, and operating work that are not justified by the current model.

## Decision

Keep local, unversioned Terraform state for the current personal and ephemeral
workloads. State remains isolated by provider and Terraform root; it is never
committed, shared, or treated as CI input.

A remote backend becomes mandatory before a shared, persistent, collaborative,
or CI-operated environment is introduced. Its bootstrap must be separate from
the workload it supports, and its state paths must remain provider- and
environment-isolated.

## Future direction

| Provider | Candidate backend | Logical path |
|---|---|---|
| AWS | S3 with a locking mechanism supported by the selected Terraform/provider versions | `serverless-order-pipeline/aws/dev/terraform.tfstate` |
| GCP | GCS | `serverless-order-pipeline/gcp/dev/terraform.tfstate` |
| Azure | Storage Account backend | `serverless-order-pipeline/azure/dev/terraform.tfstate` |

Any future backend design must define bootstrap ownership, least-privilege
access, encryption, locking, recovery, and teardown boundaries before it is
implemented.

## Consequences

- Local state is appropriate only while one operator controls disposable work.
- CI stays limited to `terraform init -backend=false` and static validation.
- No bucket, storage account, lock resource, credential, or backend block is
  created by this decision.
