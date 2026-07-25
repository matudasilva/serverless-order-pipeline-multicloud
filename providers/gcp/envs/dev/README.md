# GCP Development Deployment Stages

The GCP development environment is intentionally split into two independent
Terraform stacks. Run them in order; do not use Terraform targeting to bypass
the separation.

| Stack | Owns | Precondition |
|---|---|---|
| `bootstrap/` | Required APIs, private Artifact Registry, protected Firestore database, service accounts, and baseline IAM. | Application Default Credentials with project administration permissions. |
| `workload/` | Cloud Run services, Pub/Sub topics/subscriptions, DLQ permissions, and the Eventarc trigger. | The bootstrap stack was applied and all three images were pushed to Artifact Registry. |

Copy the example variables file inside each stack to an ignored
`terraform.tfvars` file. The identifiers and image paths remain local-only.

```bash
terraform -chdir=providers/gcp/envs/dev/bootstrap init
terraform -chdir=providers/gcp/envs/dev/bootstrap plan

# After an explicit apply and image publication:
terraform -chdir=providers/gcp/envs/dev/workload init
terraform -chdir=providers/gcp/envs/dev/workload plan
```

`apply` is a separate, explicit architect approval. No stack uses a remote
backend yet; add one before shared or CI execution.
