# AWS Decisions Carried from Legacy SDD

| Decision | Preserved rationale |
|---|---|
| DynamoDB `PAY_PER_REQUEST` | PoC traffic is unpredictable; avoid capacity planning and fixed cost. |
| Least-privilege IAM | Scope permissions to created ARNs; use the narrowest AWS-supported stream pattern. |
| SQS DLQ | Keep poison messages observable with a redrive policy. |
| Explicit CloudWatch log groups | Bound retention and avoid implicit-creation races. |
| `archive_file` Lambda packaging | Package dependency-free Python sources reproducibly with Terraform. |
| API Gateway `/orders` → SQS | Keep HTTP ingress direct to SQS; scope `SendMessage` to the queue ARN. |
| JSON success and mapped errors | Return a JSON message identifier and map SQS 4XX/5XX responses. |
| API deployment/access logs | Use a `dev` stage, trigger-based redeploy and explicit access logging. |
| Account-level CloudWatch role exception | AWS requires `Resource: "*"` for this CloudWatch Logs role; document it as the sole forced exception. |

These are AWS implementation decisions, not required GCP/Azure service mappings. Future providers
must preserve the architectural responsibility and document native trade-offs separately.
