resource "google_service_account" "ingress" {
  account_id   = "${local.name_prefix}-ingress"
  display_name = "Order pipeline ingress"
}

resource "google_service_account" "processor" {
  account_id   = "${local.name_prefix}-processor"
  display_name = "Order pipeline processor"
}

resource "google_service_account" "notifier" {
  account_id   = "${local.name_prefix}-notifier"
  display_name = "Order pipeline notifier"
}

resource "google_service_account" "pubsub_push" {
  account_id   = "${local.name_prefix}-push"
  display_name = "Pub/Sub processor push identity"
}

resource "google_service_account" "eventarc_trigger" {
  account_id   = "${local.name_prefix}-eventarc"
  display_name = "Eventarc order-created trigger identity"
}

resource "google_project_iam_member" "ingress_publish" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.ingress.email}"
}

resource "google_project_iam_member" "notifier_publish" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.notifier.email}"
}

resource "google_project_iam_member" "processor_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.processor.email}"
}

resource "google_project_iam_member" "eventarc_receive" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.eventarc_trigger.email}"
}

resource "google_service_account_iam_member" "pubsub_push_token_creator" {
  service_account_id = google_service_account.pubsub_push.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${local.pubsub_service_agent}"
}
