locals {
  petclinic_secret_env_keys = {
    POSTGRES_URL  = "PETCLINIC_DB_URL"
    POSTGRES_USER = "PETCLINIC_DB_USER"
    POSTGRES_PASS = "PETCLINIC_DB_PASSWORD"
  }
  petclinic_secret_service_account = "petclinic-secret-sa"
}

data "google_service_account" "petclinic_secret_manager_service_account" {
  account_id = local.petclinic_secret_service_account
}

resource "google_cloud_run_v2_service" "petclinic_run_service" {
  name     = "petclinic-service"
  location = var.region

  template {
    service_account = data.google_service_account.petclinic_secret_manager_service_account.email
    containers {
      image = "chabaudromain/petclinic"

      resources {
        limits = {
          memory = "1Gi"
        }
      }

      env {
        name  = "SPRING_PROFILES_ACTIVE"
        value = "postgres"
      }

      dynamic "env" {
        for_each = local.petclinic_secret_env_keys
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
    google_project_service.sql_admin_enabler
  ]
}

resource "google_cloud_run_v2_service_iam_member" "petclinic_run_service_access" {
  project  = google_cloud_run_v2_service.petclinic_run_service.project
  location = google_cloud_run_v2_service.petclinic_run_service.location
  name     = google_cloud_run_v2_service.petclinic_run_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}