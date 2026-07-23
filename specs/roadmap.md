# Roadmap

> Living document. Updated at the close of each phase (see §5, "Final
> replanning", and generally after each significant approval gate).

## Project phases

| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Repo bootstrap and workflow skill | ✅ Done | Repo created and pushed to `github.com/matudasilva/serverless-order-pipeline-aws`. `spec-feature` skill created. |
| 1 | Constitution and roadmap | ✅ Done | `constitution.md` and this `roadmap.md` approved. |
| 2 | Feature `core-pipeline` | ✅ Done | Spec/plan/tasks approved; implemented and pushed (`fmt`/`validate`/`plan` all clean, 16 resources planned). |
| 3 | Feature `api-ingestion` | ✅ Done | Approved (with design review changes: `/orders` path, JSON response mapping, error mapping, access logging); implemented and pushed (34 resources planned, 0 changed on `core-pipeline`). |
| 4 | Feature `diagrams` | ✅ Done | Both diagrams authored, reoriented to vertical per architect feedback, manually reviewed and PNG-exported for the README. |
| 5 | CI, README, and final replanning | ✅ Done | CI workflow, portfolio README (both diagrams embedded), and `specs/retrospective.md` all in place. |

**Deployment status**: nothing has been applied to AWS yet. `terraform apply`
stays a manual, architect-run action (see the README's "How to deploy")
whenever the architect chooses to stand the pipeline up — it isn't a
repo task with its own phase.

## Features (detail)

### `core-pipeline`

- **What**: DynamoDB table `orders` (PK `orderID` string, streams
  `NEW_IMAGE`), SQS queue `POC-Queue` with a restrictive access policy,
  Lambda 1 (SQS → DynamoDB) and Lambda 2 (Streams → SNS) with
  least-privilege roles, SNS topic + email subscription, event source
  mappings.
- **Improvements over the baseline**
  (`docs/reference/original-lambdas.md`): error handling with batch item
  failures in the SQS ESM, structured logging, SNS topic ARN via
  environment variable, boto3 clients initialized outside the handler,
  table name via environment variable.
- **SDD artifacts**: `specs/features/core-pipeline/`.

### `api-ingestion`

- **What**: REST API `POC-API`, `POST` method with an AWS Service
  integration to SQS (path override `account_id`/`queue`, mapping
  template `Action=SendMessage&MessageBody=$input.body`, header
  `Content-Type: application/x-www-form-urlencoded`), scoped API Gateway →
  SQS role, deployment + `dev` stage.
- **Depends on**: the `POC-Queue` SQS queue from `core-pipeline`.
- **SDD artifacts**: `specs/features/api-ingestion/`.

### `diagrams`

- **What**: two Excalidraw diagrams with a consistent visual style.
  1. `docs/diagrams/architecture.excalidraw` — solution architecture
     (Client → API Gateway → SQS → Lambda 1 → DynamoDB → Streams →
     Lambda 2 → SNS → Email), grouped by layer (ingestion / processing /
     persistence / notification), labeled arrows, and a legend with the
     region and a least-privilege IAM note.
  2. `docs/diagrams/sdd-terraform-workflow.excalidraw` — the SDD +
     Terraform workflow with AI assistance, with "Architect (human)" /
     "Coding agent (AI)" swimlanes, visually differentiated approval
     gates, and the manual `apply` step highlighted outside the agent
     loop.
- **SDD artifacts**: `specs/features/diagrams/`.

### CI, README, and final replanning (Phase 5)

- **What**: GitHub Actions workflow (`fmt -check` + `validate`, no AWS
  credentials, no plan/apply), full portfolio README (problem statement
  with the `architecture.excalidraw` diagram exported and embedded,
  highlighted architecture decisions, repo structure, how to
  deploy/destroy, a "Development workflow" section with the
  `sdd-terraform-workflow.excalidraw` diagram exported and embedded), an
  update to this roadmap marking completed features, and a
  `specs/retrospective.md` with lessons learned from the SDD process.
- Not modeled as a separate `spec-feature` feature, since it's
  cross-cutting closing work, but it still follows the same STOP criteria
  between significant steps (e.g. before preparing repo/push commands,
  which was already run manually in Phase 0 for this repo).

## Explicitly out of scope

- Multi-environment (staging/prod) — the PoC lives only in `envs/dev/`.
- Multi-region.
- API authentication/authorization (the original exercise doesn't require
  it; would be documented as a future improvement if added).
- Advanced observability (dashboards, alarms) beyond the Lambdas'
  structured logging.
