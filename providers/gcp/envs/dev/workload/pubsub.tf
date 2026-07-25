resource "google_pubsub_topic" "orders" {
  name = "${local.name_prefix}-orders"
  message_storage_policy { allowed_persistence_regions = [var.region] }
}

resource "google_pubsub_topic" "orders_dlq" {
  name = "${local.name_prefix}-orders-dlq"
  message_storage_policy { allowed_persistence_regions = [var.region] }
}

resource "google_pubsub_topic" "notifications" {
  name = "${local.name_prefix}-notifications"
  message_storage_policy { allowed_persistence_regions = [var.region] }
}

resource "google_pubsub_topic_iam_member" "dlq_pubsub_publish" {
  topic  = google_pubsub_topic.orders_dlq.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_pubsub_subscription" "orders_dlq_inspection" {
  name                       = "${local.name_prefix}-orders-dlq-inspection"
  topic                      = google_pubsub_topic.orders_dlq.id
  ack_deadline_seconds       = 60
  message_retention_duration = "86400s"

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_subscription" "orders_processing" {
  name                       = "${local.name_prefix}-orders-processing"
  topic                      = google_pubsub_topic.orders.id
  ack_deadline_seconds       = 60
  message_retention_duration = "86400s"

  push_config {
    push_endpoint = google_cloud_run_v2_service.processor.uri
    oidc_token { service_account_email = data.google_service_account.pubsub_push.email }
  }
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.orders_dlq.id
    max_delivery_attempts = 5
  }
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}

resource "google_pubsub_subscription_iam_member" "processing_dlq_ack" {
  subscription = google_pubsub_subscription.orders_processing.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_pubsub_subscription" "notifications_inspection" {
  name                       = "${local.name_prefix}-notifications-inspection"
  topic                      = google_pubsub_topic.notifications.id
  ack_deadline_seconds       = 60
  message_retention_duration = "86400s"

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }
}
