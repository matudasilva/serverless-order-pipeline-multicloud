# GCP Provider Design

GCP is not implemented or deployed yet. Its approved design is isolated here
to preserve the AWS baseline and to make provider-specific decisions explicit.

## Proposed layout

| Path | Responsibility |
|---|---|
| `envs/dev/` | GCP Terraform stack, provider configuration, service accounts, Cloud Run, Pub/Sub, Firestore, Eventarc, and observability. |
| `src/ingress/` | HTTP v1 validation and `202` queued response. |
| `src/processor/` | Pub/Sub push-envelope decoding and Firestore persistence. |
| `src/notifier/` | Firestore Eventarc decoding and notification-topic publishing. |
| `docs/diagrams/` | Provider architecture design and its README asset. |
| `docs/` | Provider decisions, test evidence, cost controls, and teardown record. |

The implementation must satisfy
[`../../docs/contracts/order-pipeline-v1.md`](../../docs/contracts/order-pipeline-v1.md)
and ORQ-002 before any cloud resource is created.

## Container images

Each service has a self-contained Dockerfile. Build from `providers/gcp/src/`
so that the shared dependency manifest is available to the Docker build:

```bash
docker build -f ingress/Dockerfile -t ingress:dev .
docker build -f processor/Dockerfile -t processor:dev .
docker build -f notifier/Dockerfile -t notifier:dev .
```

The Terraform development variables refer to the corresponding future images
in the private Artifact Registry repository. Building, pushing, and applying
remain separate, explicitly approved cloud operations.
