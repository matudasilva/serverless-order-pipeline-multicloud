**Authorship:** Codex (GPT-5) through reverse engineering of the Notion adoption plan and repository state, validated by Matías.
**Date:** 2026-07-23
**Version:** v1.1

# Roadmap — Serverless Order Pipeline Multicloud

## Starting State

The AWS baseline was imported into an independent repository and reorganized under `providers/aws/`. Terraform validates and the Python Lambdas compile. Its inherited SDD knowledge is synthesized into AWS baseline and decision documentation; the original repository remains the historical source.

## Phases

| Phase | Objective | Status |
|---|---|---|
| 0 | Preserve `serverless-order-pipeline-aws` as independent evidence | Complete |
| 1 | Create the multicloud repository and import the AWS baseline | Complete |
| 2 | Isolate AWS under `providers/aws/` and correct affected paths | Complete |
| 3 | Adopt AI Together Framework V3 in brownfield mode | Complete |
| 4 | Migrate requirements, decisions, ADRs, and learnings from the inherited SDD process | Complete |
| 5 | Retire standalone SDD governance after verified migration | Complete |
| 6 | Define the shared functional order contract and test payloads | Complete |
| 7 | Design the GCP variant through an approved design ORQ | Complete |
| 8 | Implement, validate, and manually test the GCP variant | Complete |
| 9 | Create the Azure Free account after GCP is closed and learnings are recorded | Complete |
| 10 | Design, implement, and validate the Azure variant | Complete |
| 11 | Compare services, retries, DLQ behavior, IAM, observability, costs, and portability | In progress |

## Next Work

The next work is cross-provider consistency, conformance automation, and an
evidence-based comparison. The shared functional contract and portable test
payloads are recorded in
[`docs/contracts/order-pipeline-v1.md`](../../docs/contracts/order-pipeline-v1.md).
AWS remains a historical functional baseline and is not v1-conformant; provider
equivalence is based on responsibility rather than service-name matching.

## Dependencies and Risks

- Standalone SDD governance has been retired from this repository. The original AWS repository retains its historical records; active decisions live in the Framework constitution and provider documentation.
- GCP was deployed, manually validated, and then torn down; its record covers HTTP ingress, Pub/Sub and DLQ, runtime, Firestore/Eventarc, IAM, notifications, regions, costs, and teardown boundaries.
- Azure was implemented and deployed ephemerally. Its sanitized smoke evidence covers HTTP responses and queue drainage, not complete end-to-end conformance.
