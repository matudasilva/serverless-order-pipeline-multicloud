**Authorship:** Codex (GPT-5) through reverse engineering of the Notion adoption plan and repository state, validated by Matías.
**Date:** 2026-07-23
**Version:** v1.0

# Roadmap — Serverless Order Pipeline Multicloud

## Starting State

The AWS baseline was imported into an independent repository and reorganized under `providers/aws/`. Terraform validates and the Python Lambdas compile. The inherited SDD history remains temporarily as evidence until its knowledge has been explicitly migrated.

## Phases

| Phase | Objective | Status |
|---|---|---|
| 0 | Preserve `serverless-order-pipeline-aws` as independent evidence | Complete |
| 1 | Create the multicloud repository and import the AWS baseline | Complete |
| 2 | Isolate AWS under `providers/aws/` and correct affected paths | Complete |
| 3 | Adopt AI Together Framework V3 in brownfield mode | Complete |
| 4 | Migrate requirements, decisions, ADRs, and learnings from the inherited SDD process | Pending |
| 5 | Retire standalone SDD governance after verified migration | Pending |
| 6 | Define the shared functional order contract and test payloads | Pending |
| 7 | Design the GCP variant through an approved design ORQ | Pending |
| 8 | Implement, validate, and manually test the GCP variant | Pending |
| 9 | Create the Azure Free account after GCP is closed and learnings are recorded | Pending |
| 10 | Design and implement the Azure variant | Pending |
| 11 | Compare services, retries, DLQ behavior, IAM, observability, costs, and portability | Pending |

## Next ORQ

Open the ORQ that migrates SDD knowledge. Do not remove `specs/` or implement GCP until those dependencies are closed.

## Dependencies and Risks

- SDD migration must synthesize current decisions into the Constitution, AWS documentation, and learning records; it must not copy the artifacts mechanically.
- The GCP variant requires a design review covering HTTP ingress, Pub/Sub and DLQ, runtime, Firestore/Eventarc, IAM, notifications, regions, costs, and teardown.
- The Azure variant depends on the learnings recorded after GCP and must not be brought forward to avoid premature cost and complexity.
