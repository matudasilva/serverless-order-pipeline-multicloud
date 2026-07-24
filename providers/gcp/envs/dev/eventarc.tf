resource "google_eventarc_trigger" "order_created" {
  name     = "${local.name_prefix}-order-created"
  location = var.region

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.firestore.document.v1.created"
  }
  matching_criteria {
    attribute = "database"
    value     = "(default)"
  }
  matching_criteria {
    attribute = "document"
    value     = "orders/{orderId}"
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.notifier.name
      region  = var.region
    }
  }

  service_account = google_service_account.eventarc_trigger.email

  depends_on = [
    google_project_service.required["eventarc.googleapis.com"],
    google_firestore_database.orders,
    google_cloud_run_v2_service_iam_member.notifier_eventarc,
    google_project_iam_member.eventarc_receive,
  ]
}
