resource "google_artifact_registry_repository" "runtime_images" {
  location      = var.region
  repository_id = "order-pipeline"
  description   = "Private runtime images for the order pipeline"
  format        = "DOCKER"

  depends_on = [google_project_service.required["artifactregistry.googleapis.com"]]
}
