locals {
  name_prefix          = "order-pipeline-gcp"
  pubsub_service_agent = "service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  labels               = { project = "serverless-order-pipeline", provider = "gcp" }
}
