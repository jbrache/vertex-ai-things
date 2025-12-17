/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

output "project_id" {
  description = "The Google Cloud project ID"
  value       = var.project_id
}

output "project_number" {
  description = "The Google Cloud project number"
  value       = data.google_project.project.number
}

output "location" {
  description = "Multi-Region location used for KMS and GCS"
  value       = var.location
}

output "kms_key_ring_id" {
  description = "The ID of the KMS key ring"
  value       = google_kms_key_ring.gemini_keyring.id
}

output "kms_crypto_key_id" {
  description = "The ID of the KMS crypto key"
  value       = google_kms_crypto_key.gemini_key.id
}

output "kms_crypto_key_name" {
  description = "The resource name of the KMS crypto key"
  value       = google_kms_crypto_key.gemini_key.name
}

output "bucket_name" {
  description = "The name of the GCS bucket"
  value       = google_storage_bucket.gemini_data_bucket.name
}

output "bucket_url" {
  description = "The URL of the GCS bucket"
  value       = google_storage_bucket.gemini_data_bucket.url
}

output "gcs_service_agent" {
  description = "The GCS service agent email"
  value       = "service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
}

output "discovery_engine_service_agent" {
  description = "The Discovery Engine service agent email"
  value       = "service-${data.google_project.project.number}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
}

output "cmek_config_api_endpoint" {
  description = "API endpoint to verify the CMEK configuration"
  value       = "https://${var.location}-discoveryengine.googleapis.com/v1/projects/${var.project_id}/locations/${var.location}/cmekConfigs/${var.cmek_config_id}"
}

output "next_steps" {
  description = "Next steps to complete the setup"
  value       = <<-EOT
    Setup Complete! Next steps:

    1. Wait 15 minutes for the CMEK configuration to propagate.

    2. Verify CMEK configuration:
       curl -X GET \
         -H "Authorization: Bearer $(gcloud auth print-access-token)" \
         "https://${var.location}-discoveryengine.googleapis.com/v1/projects/${var.project_id}/locations/${var.location}/cmekConfigs/${var.cmek_config_id}"

    3. Upload data to the GCS bucket:
       gsutil cp your-file.pdf gs://${google_storage_bucket.gemini_data_bucket.name}/

    4. Create a new Data Store in the Gemini Enterprise console or via API.
       It should automatically use your CMEK key.

    5. Verify encryption in the GCS Console:
       https://console.cloud.google.com/storage/browser/${google_storage_bucket.gemini_data_bucket.name}

    Important Notes:
    - Only NEW Data Stores created after CMEK registration will use CMEK.
    - Existing Data Stores cannot be migrated to CMEK.
    - Source data in GCS: encrypted with ${google_kms_crypto_key.gemini_key.id}
    - Indexed data in Discovery Engine: will use the same key for new stores.
  EOT
}
