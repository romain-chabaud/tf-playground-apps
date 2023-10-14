resource "google_project_service" "cloud_run_enabler" {
  service = "run.googleapis.com"
}

resource "google_project_service" "sql_admin_enabler" {
  service = "sqladmin.googleapis.com"
}

resource "google_project_service" "secret_manager_enabler" {
  service = "secretmanager.googleapis.com"
}