**Authorship:** Codex (GPT-5) through reverse engineering of the Notion adoption plan and repository state, validated by Matías.
**Date:** 2026-07-23
**Version:** v1.1

# Roadmap — Serverless Order Pipeline Multicloud

## Starting State

The AWS baseline was imported into an independent repository and reorganized under `providers/aws/`. Terraform validates and the Python Lambdas compile. Its inherited SDD knowledge is synthesized into AWS baseline/decision documentation; the original artifacts remain as historical evidence pending a Phase 5 retention decision.

## Phases

| Phase | Objective | Status |
|---|---|---|
| 0 | Preserve `serverless-order-pipeline-aws` as independent evidence | Complete |
| 1 | Create the multicloud repository and import the AWS baseline | Complete |
| 2 | Isolate AWS under `providers/aws/` and correct affected paths | Complete |
| 3 | Adopt AI Together Framework V3 in brownfield mode | Complete |
| 4 | Migrate requirements, decisions, ADRs, and learnings from the inherited SDD process | Complete |
| 5 | Retire standalone SDD governance after verified migration | Pending |
| 6 | Define the shared functional order contract and test payloads | Pending |
| 7 | Design the GCP variant through an approved design ORQ | Pending |
| 8 | Implement, validate, and manually test the GCP variant | Pending |
| 9 | Create the Azure Free account after GCP is closed and learnings are recorded | Pending |
| 10 | Design and implement the Azure variant | Pending |
| 11 | Compare services, retries, DLQ behavior, IAM, observability, costs, and portability | Pending |

## Next Work

Decide whether Phase 5 archives or retires standalone SDD governance. Do not remove `specs/`, the legacy skill, or historical diagrams until that decision explicitly covers their remaining references. After Phase 5 is resolved, define the shared functional order contract before designing GCP.

## Dependencies and Risks

- SDD migration is complete; Phase 5 must preserve or retire remaining references consistently rather than deleting isolated files.
- The GCP variant requires a design review covering HTTP ingress, Pub/Sub and DLQ, runtime, Firestore/Eventarc, IAM, notifications, regions, costs, and teardown.
- The Azure variant depends on the learnings recorded after GCP and must not be brought forward to avoid premature cost and complexity.
