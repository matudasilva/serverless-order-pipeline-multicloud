terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google" {
  alias                 = "budget"
  project               = var.project_id
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}
