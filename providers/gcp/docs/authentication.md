# GCP Authentication

Local Terraform development uses Application Default Credentials (ADC) from
`gcloud auth application-default login`. No access-key pair or downloaded
service-account JSON key is stored in this repository.

The local `terraform.tfvars` holds only the project identifier and is ignored
by Git. Future CI must use service-account impersonation or Workload Identity
Federation with least-privilege roles; it must not use a long-lived key file.
