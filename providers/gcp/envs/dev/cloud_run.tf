resource "google_cloud_run_v2_service" "ingress" {
  name     = "${local.name_prefix}-ingress"
  location = var.region

  template {
    service_account = google_service_account.ingress.email
    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
    containers {
      image = var.ingress_image
      resources { limits = { cpu = "1", memory = "512Mi" } }
      env {
        name  = "ORDERS_TOPIC"
        value = google_pubsub_topic.orders.name
      }
    }
  }

  depends_on = [
    google_project_service.required["run.googleapis.com"],
    google_artifact_registry_repository.runtime_images,
  ]
}

resource "google_cloud_run_v2_service" "processor" {
  name     = "${local.name_prefix}-processor"
  location = var.region

  template {
    service_account = google_service_account.processor.email
    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
    containers {
      image = var.processor_image
      resources { limits = { cpu = "1", memory = "512Mi" } }
    }
  }

  depends_on = [
    google_project_service.required["run.googleapis.com"],
    google_artifact_registry_repository.runtime_images,
  ]
}

resource "google_cloud_run_v2_service" "notifier" {
  name     = "${local.name_prefix}-notifier"
  location = var.region

  template {
    service_account = google_service_account.notifier.email
    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }
    containers {
      image = var.notifier_image
      resources { limits = { cpu = "1", memory = "512Mi" } }
      env {
        name  = "NOTIFICATIONS_TOPIC"
        value = google_pubsub_topic.notifications.name
      }
    }
  }

  depends_on = [
    google_project_service.required["run.googleapis.com"],
    google_artifact_registry_repository.runtime_images,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "notifier_eventarc" {
  name     = google_cloud_run_v2_service.notifier.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.eventarc_trigger.email}"
}

resource "google_cloud_run_v2_service_iam_member" "ingress_public" {
  name     = google_cloud_run_v2_service.ingress.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service_iam_member" "processor_push" {
  name     = google_cloud_run_v2_service.processor.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pubsub_push.email}"
}
