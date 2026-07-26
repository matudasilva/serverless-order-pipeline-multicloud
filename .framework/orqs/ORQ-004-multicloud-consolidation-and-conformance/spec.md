---
orq: ORQ-004
title: "Multicloud consolidation and conformance"
state: Closed Locally
phase: Validate
scope: multicloud-consolidation
authored_by:
  - agent: "Codex (GPT-5)"
    role: "orchestrator"
updated: 2026-07-26
---

| ORQ | Title | State | Phase | Updated |
|---|---|---|---|---|
| ORQ-004 | Multicloud consolidation and conformance | Closed Locally | Validate | 2026-07-26 |

## Objective

Consolidate the repository into an evidence-based multicloud portfolio project.
Align public documentation, framework roadmap, CI, state strategy, comparison
documentation, and portable HTTP conformance tooling with the verified state of
the AWS, GCP, and Azure variants.

## Confirmed baseline

- AWS is a historical functional baseline, not Order Pipeline v1-conformant:
  it accepts raw request bodies, persists `orderID`, and returns `200`.
- GCP has split bootstrap and workload Terraform roots, manual validation, and
  verified teardown evidence; it has no Python unit tests.
- Azure has one Terraform root, Python unit tests, an ephemeral deployment and
  sanitized HTTP/queue-drain evidence; complete v1 conformance is not proven.
- The current CI validates AWS and Azure but omits GCP and has incomplete path
  filters.
- No Terraform configuration declares a remote backend. GCP explicitly
  documents local state; AWS and Azure use Terraform's default local backend.

## Scope

### Included

1. Reconcile README, constitutional roadmap, provider status, repository
   structure, terminology, non-goals, and evidence boundaries.
2. Add non-mutating GCP Terraform validation and coherent provider/contract
   path filters to GitHub Actions.
3. Record the current local-state model and a future remote-backend strategy
   without creating backends or cloud resources.
4. Add a concise, evidence-classified multicloud comparison covering
   architecture, identity, delivery semantics, operability, and cost guardrails.
5. Implement and locally test a provider-neutral HTTP contract runner using
   the existing Order Pipeline v1 payloads. It must not run against cloud in CI.
6. Produce an AWS ingress decision record that compares API Gateway validation,
   a Lambda ingress, and explicit partial conformance. It must remain pending
   architect approval and must not change AWS infrastructure or runtime code.
7. Address safe quality gaps: documentation links, ignore coverage, version and
   runtime documentation consistency, scripts, and diagram-asset conventions.

### Excluded

- Terraform apply, destroy, cloud resource changes, publication, real-endpoint
  smoke tests, plans requiring cloud authentication, and credential use.
- AWS ingress architecture changes, including any new Lambda.
- Migration of AWS persisted `orderID` to `orderId`.
- Remote backend implementation, bootstrap storage, or state migration.
- A claim of end-to-end provider conformance without complete recorded evidence.

## Phases

| Phase | Outcome | Approval gate |
|---|---|---|
| 1 | Documentation and roadmap consistency | No architecture change |
| 2 | GCP CI and provider-aware validation filters | No cloud credentials or mutation |
| 3 | Current/future state strategy decision | Documentation only |
| 4 | Evidence-based multicloud comparison | Facts, decisions, inferences, and limits labelled |
| 5 | Portable HTTP conformance runner and local tests | No cloud execution from CI |
| 6 | AWS ingress ADR | Architect approval before implementation |
| 7 | Cross-cutting quality and local validation | All findings reported honestly |

## Decisions requiring architect approval

1. Whether AWS retains explicit partial conformance, uses API Gateway-only
   validation, or gains a Lambda ingress.
2. Whether and how AWS `orderID` could migrate to the target `orderId` term.
3. Whether Azure should adopt the AWS/GCP SVG diagram convention or the project
   should standardize on Excalidraw plus PNG.
4. Any future remote backend implementation, including its bootstrap boundary.

## Acceptance Criteria

| ID | Criterion | Evidence |
|---|---|---|
| AC1 | Provider-status claims are supported by code, tests, commits, and validation records; Azure is not described as future work. | README and roadmap review |
| AC2 | Repository structure and non-goals describe only current paths and scope. | README review |
| AC3 | GCP static Terraform validation runs without credentials for both roots. | CI workflow and local command record |
| AC4 | Current and future provider-isolated state strategy is documented without backend implementation. | Decision record |
| AC5 | Comparison claims identify fact, decision, inference, limitation, or future work. | Comparison documentation |
| AC6 | The runner validates all portable HTTP payloads locally with mocks and emits sanitized machine-readable evidence. | Tests and runner documentation |
| AC7 | AWS remains non-conformant until an approved architecture change and evidence establish otherwise. | AWS ADR and status table |
| AC8 | Local non-mutating Terraform, Python, workflow, link, secret-scan, and diff checks are recorded with their actual result. | Validation evidence |

## Review and checkpoint

The architect explicitly approved this scope and plan on 2026-07-26. The
external-reviewer extension is disabled by project configuration, so the plan
checkpoint records reduced reviewer independence rather than implying an
independent review.
