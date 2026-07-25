data "google_artifact_registry_repository" "runtime_images" {
  location      = var.region
  repository_id = "order-pipeline"
}

data "google_service_account" "ingress" {
  account_id = "${local.name_prefix}-ingress"
}

data "google_service_account" "processor" {
  account_id = "${local.name_prefix}-processor"
}

data "google_service_account" "notifier" {
  account_id = "${local.name_prefix}-notifier"
}

data "google_service_account" "pubsub_push" {
  account_id = "${local.name_prefix}-push"
}

data "google_service_account" "eventarc_trigger" {
  account_id = "${local.name_prefix}-eventarc"
}
