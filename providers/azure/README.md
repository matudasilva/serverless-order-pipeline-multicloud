# Azure provider

Azure is implemented as an ephemeral, low-volume variant of the shared Order
Pipeline v1 contract. The design and approved architecture diagram are in
[`docs/diagrams/architecture.excalidraw`](docs/diagrams/architecture.excalidraw)
and its README asset is `docs/diagrams/architecture.png`.

## Architecture

<img src="docs/diagrams/architecture.png" width="700"
  alt="Azure order pipeline architecture: public HTTP ingress, Service Bus, private processor, Cosmos DB Change Feed, notifier, and notification queue">

## Local validation

Run the unit tests without Azure credentials:

```bash
python -m pytest providers/azure/tests
```

Format and validate the Terraform root without a backend:

```bash
terraform -chdir=providers/azure/envs/dev fmt -check
terraform -chdir=providers/azure/envs/dev init -backend=false
terraform -chdir=providers/azure/envs/dev validate
```

The implementation deliberately contains no committed `terraform.tfvars`,
state, credentials, connection strings, subscription IDs, or tenant IDs.
`terraform apply`, `terraform destroy`, account setup, and API registration are
manual architect actions and are not run by this repository workflow.

Each Function App is linked to the Terraform-managed Application Insights
resource using a Terraform reference, never a literal connection string in
source. Azure Functions requires that setting for monitoring; the resulting
value is sensitive runtime configuration and remains outside version control.

Terraform packages each Function source directory into a reproducible ZIP under
the local Terraform working directory. The package includes the pinned
`requirements.txt` and the shared `common` module. Dependency installation is
delegated to the Functions deployment build. Flex Consumption does not
reliably accept Terraform ZIP deployment through its SCM endpoint in this
environment, so publishing remains a separate, explicitly approved deployment
gate. Use [`scripts/publish-functions.sh`](scripts/publish-functions.sh) with
Azure Functions Core Tools and remote build after a successful infrastructure
apply. No package is uploaded during local validation.

Core Tools may manage the deployment-storage setting required by Flex
publication. Terraform deliberately preserves that platform-managed setting
instead of treating it as a source-controlled secret.

For the complete deployment sequence, recovery procedures, and known Azure
platform constraints, read
[`docs/deployment-and-troubleshooting.md`](docs/deployment-and-troubleshooting.md).
For the concise history of the incident diagnosis and its permanent safeguards,
read [`docs/infrastructure-incident-resolution.md`](docs/infrastructure-incident-resolution.md).

The first implementation gate must prove the selected Python Azure Functions
Cosmos trigger extension, managed-identity leases, custom data-plane roles,
and the broker-managed Service Bus dead-letter subqueue before any cloud deployment.
