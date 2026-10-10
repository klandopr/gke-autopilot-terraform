terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {
  description = "ID del proyecto de GCP"
  type        = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "container" {
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# Autopilot: Google gestiona los nodos, solo pagas los pods
resource "google_container_cluster" "demo" {
  name                = "gke-demo"
  location            = var.region
  enable_autopilot    = true
  deletion_protection = false # permite terraform destroy

  depends_on = [google_project_service.container]
}

output "cluster_name" {
  value = google_container_cluster.demo.name
}

output "get_credentials" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.demo.name} --region ${var.region} --project ${var.project_id}"
}
