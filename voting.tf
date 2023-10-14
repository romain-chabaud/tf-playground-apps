locals {
  voting_app_image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.voting_repository.repository_id}/voting-app"
  voting_secret_env_keys = {
    INSTANCE_HOST = "VOTING_DB_IP"
    DB_NAME       = "VOTING_DB_NAME"
    DB_USER       = "VOTING_DB_USER"
    DB_PASS       = "VOTING_DB_PASSWORD"
  }
  voting_secret_service_account = "voting-secret-sa"
}

data "google_service_account" "voting_secret_manager_service_account" {
  account_id = local.voting_secret_service_account
}

resource "google_project_service" "artifact_registry_enabler" {
  service = "artifactregistry.googleapis.com"
}

resource "google_artifact_registry_repository" "voting_repository" {
  location      = var.region
  repository_id = "voting-repository"
  format        = "DOCKER"

  depends_on = [google_project_service.artifact_registry_enabler]
}

resource "null_resource" "voting_app_image_creation" {
  provisioner "local-exec" {
    command = <<EOT
    rm -fr java-docs-samples &&
    git clone https://github.com/GoogleCloudPlatform/java-docs-samples.git &&
    cd java-docs-samples/cloud-sql/postgres/servlet &&
    mvn clean package com.google.cloud.tools:jib-maven-plugin:2.8.0:build -Dimage=${local.voting_app_image} -DskipTests
    EOT
  }

  depends_on = [google_artifact_registry_repository.voting_repository]
}

resource "google_cloud_run_v2_service" "voting_run_service" {
  name     = "voting-service"
  location = var.region

  template {
    service_account = data.google_service_account.voting_secret_manager_service_account.email
    containers {
      image = local.voting_app_image

      env {
        name  = "DB_PORT"
        value = 5432
      }

      dynamic "env" {
        for_each = local.voting_secret_env_keys
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "1"
            }
          }
        }
      }

    }
  }

  depends_on = [
    google_project_service.cloud_run_enabler,
    google_project_service.sql_admin_enabler,
    null_resource.voting_app_image_creation
  ]
}

resource "google_cloud_run_v2_service_iam_member" "voting_run_service_access" {
  project  = google_cloud_run_v2_service.voting_run_service.project
  location = google_cloud_run_v2_service.voting_run_service.location
  name     = google_cloud_run_v2_service.voting_run_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}