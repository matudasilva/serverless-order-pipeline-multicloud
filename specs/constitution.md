# Project Constitution

> `serverless-order-pipeline-aws` — Living document. Any change to this file
> requires explicit approval from the architect (the user).

## 1. Mission

This repository is a **public portfolio** that demonstrates, through a
concrete and bounded use case, three capabilities:

1. **Serverless architecture on AWS** — implementation of the PoC described
   in "Exercise 1 – Building a Proof of Concept for a Serverless Solution"
   (AWS Architecting Solutions): `API Gateway → SQS → Lambda 1 → DynamoDB →
   DynamoDB Streams → Lambda 2 → SNS (email)`.
2. **Infrastructure as code with Terraform** — the full pipeline is defined
   and deployed via Terraform, with no manual console clicks.
3. **Spec-Driven Development (SDD) methodology with coding agents** — the
   process used to build this repo (specs, plans, tasks, human approval
   gates) is itself part of what's on display, not just the end result.

**Audience**: technical reviewers and architects evaluating design
capability and auditable collaboration with AI coding agents.

**Language**: all repository content is written in English. The target
audience for this portfolio spans international, primarily English-speaking
technical markets, so English maximizes the portfolio's reach and
comprehension.

**Framing**: "AI-assisted development workflow" with human architectural
ownership — the agent executes, the architect designs, reviews, and approves
each stage.

**Scope**: this is a PoC for a single exercise. There is no pursuit of
multi-environment support (staging/prod), multi-region deployment, or
production-grade robustness beyond what the exercise itself and its
documented improvements require. Any feature that exceeds this scope must be
explicitly justified in the roadmap before implementation.

## 2. Technology stack

Stack versions and pins (Terraform, providers, runtime, CI) are the
single source of truth in [`specs/tech-stack.md`](tech-stack.md), kept as
a separate living document so it can evolve (e.g. version bumps) without
touching this constitution. This constitution keeps only the constraints:

**Cost constraint**: resources must stay within (or very close to) the AWS
free tier. No resources that generate significant fixed cost (e.g. NAT
Gateways, always-on instances) are provisioned.

**Deployment constraint**: `terraform apply` is **deferred** — the agent
only runs `fmt`, `validate`, and `plan` locally. The architect runs `apply`
manually once all features are code-complete.

**Security constraint**: least privilege by design — see §3.

## 3. Repo and process conventions

### SDD process

- Each feature follows the **specify → plan → tasks → implement →
  validate** cycle, executed with the `spec-feature` skill
  (`.claude/skills/spec-feature/`).
- The agent stops at the end of each approval stage, waiting for explicit
  sign-off from the architect. It never moves to `implement` before
  `spec.md` and `plan.md` are approved.
- Every SDD artifact lives in `specs/` and is committed — it's part of the
  portfolio, not disposable material.
- `spec.md` and `plan.md` open with a "Review summary" (≤10 lines):
  decisions needing approval, deviations from the baseline, and key
  risks. Full detail follows below it, to keep review bandwidth low.
- When an instruction or requirement is ambiguous: STOP and ask. Do not
  improvise architecture or scope decisions.

### IAM and security

- No IAM policy uses `Resource: "*"`. All policies are scoped to the ARNs
  of the resources created by this project. This is a deliberate
  improvement over the original exercise (which doesn't require it) and
  must be documented as an ADR in the `plan.md` of the feature that
  introduces it. The one known exception is `api-ingestion`'s
  account-level API Gateway CloudWatch role, which AWS itself refuses to
  accept scoped below `Resource: "*"` — see
  [`api-ingestion` ADR-10](features/api-ingestion/plan.md) for why this
  is a structural AWS constraint, not a choice.

### Terraform structure

- `envs/dev/` holds the full PoC stack.
- `modules/` is used **only** when there is clear reuse across resources
  (no modularizing for its own sake in a PoC of this size). Any proposed
  module must be justified in the corresponding `plan.md`.
- Terraform's `required_version` is pinned consistently in `providers.tf`
  and in the CI workflow.
- The `hashicorp/aws` provider version constraint in `providers.tf` matches
  what `specs/tech-stack.md` declares, same as `required_version`.

### Git and commits

- One task = one commit by default; deviations (e.g. two trivial tasks
  touching the same file) are allowed and must be noted in the
  corresponding `tasks.md`.
- Commit messages are written in English, Conventional Commits format.
- All repository content — specs, plans, tasks, docs, README, code
  comments, and commit messages — is written in English.

### CI

- The GitHub Actions workflow runs `terraform fmt -check` and
  `terraform validate` only. It uses no AWS credentials and runs neither
  `plan` nor `apply` in CI.
