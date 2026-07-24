locals {
  name_prefix          = "order-pipeline-gcp"
  pubsub_service_agent = "service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  required_apis = toset([
    "artifactregistry.googleapis.com",
    "eventarc.googleapis.com",
    "firestore.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
  ])
}
