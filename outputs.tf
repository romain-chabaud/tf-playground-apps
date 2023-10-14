output "petclinic_app_url" {
  value = google_cloud_run_v2_service.petclinic_run_service.uri
}

output "voting_app_url" {
  value = google_cloud_run_v2_service.voting_run_service.uri
}