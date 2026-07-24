# GCP Provider

GCP is implemented and manually validated as the first deployed provider
variant after the AWS baseline. Provider-specific decisions, Terraform stages,
and validation evidence remain isolated here.

## Layout

| Path | Responsibility |
|---|---|
| `envs/dev/` | GCP Terraform stack, provider configuration, service accounts, Cloud Run, Pub/Sub, Firestore, Eventarc, and observability. |
| `src/ingress/` | HTTP v1 validation and `202` queued response. |
| `src/processor/` | Pub/Sub push-envelope decoding and Firestore persistence. |
| `src/notifier/` | Firestore Eventarc decoding and notification-topic publishing. |
| `docs/diagrams/` | Provider architecture design and its README asset. |
| `docs/` | Provider decisions, test evidence, cost controls, and teardown record. |

The implementation satisfies
[`../../docs/contracts/order-pipeline-v1.md`](../../docs/contracts/order-pipeline-v1.md)
and the approved ORQ-002 design. See the
[validation record](docs/validation.md) for manual deployment evidence.

The development Terraform configuration is split into
[`envs/dev/bootstrap/`](envs/dev/bootstrap/) and
[`envs/dev/workload/`](envs/dev/workload/). See the
[deployment-stage guide](envs/dev/README.md) for the required order and
approval boundary.

## Container images

Each service has a self-contained Dockerfile. Build from `providers/gcp/src/`
so that the shared dependency manifest is available to the Docker build:

```bash
docker build -f ingress/Dockerfile -t ingress:dev .
docker build -f processor/Dockerfile -t processor:dev .
docker build -f notifier/Dockerfile -t notifier:dev .
```

The Terraform development variables refer to images in the private Artifact
Registry repository. Building, pushing, and applying remain separate,
explicitly approved cloud operations.
