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

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  # The project where your resources will be created
  project = var.project_id

  # The project that has the necessary quota and billing enabled
  # billing_project = var.project_id

  # This setting ensures the provider uses the billing_project for quota checks
  # user_project_override = true
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "google_project" "project" {
  project_id = var.project_id
}

# ==============================================================================
# 1. Enable Required APIs
# ==============================================================================

resource "google_project_service" "required_apis" {
  for_each = var.enable_apis ? toset([
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
    "discoveryengine.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ]) : toset([])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Wait after enabling APIs
resource "time_sleep" "wait_for_project_apis" {
  depends_on = [
    google_project_service.required_apis
  ]
  create_duration = "5s"
}

# ============================================
# Generate service identity for services (IAM)
# ============================================
# This activates the service agent for a given API
resource "google_project_service_identity" "service_kms_identity" {
  provider = google-beta
  project = var.project_id
  service = "cloudkms.googleapis.com"
  depends_on = [time_sleep.wait_for_project_apis]
}

resource "google_project_service_identity" "service_discoveryengine_identity" {
  provider = google-beta
  project = var.project_id
  service = "discoveryengine.googleapis.com"
  depends_on = [time_sleep.wait_for_project_apis]
}

resource "google_project_service_identity" "service_storage_identity" {
  provider = google-beta
  project = var.project_id
  service = "storage.googleapis.com"
  depends_on = [time_sleep.wait_for_project_apis]
}

# Wait for Service Identity Creation
resource "time_sleep" "wait_for_service_identity_creation" {
  depends_on = [
    google_project_service_identity.service_kms_identity,
    google_project_service_identity.service_discoveryengine_identity,
    google_project_service_identity.service_storage_identity
  ]
  create_duration = "5s"
}

# ==============================================================================
# 2. Create Cloud KMS Key Ring and Key
# ==============================================================================

resource "google_kms_key_ring" "gemini_keyring" {
  name     = var.key_ring_name
  location = var.location

  depends_on = [google_project_service.required_apis, time_sleep.wait_for_service_identity_creation]
}

resource "google_kms_crypto_key" "gemini_key" {
  name     = var.key_name
  key_ring = google_kms_key_ring.gemini_keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  # Per Vertex AI Search documentation, key rotation should be set to "Never" (manual rotation)
  # to avoid indexing interruptions. Uncomment and adjust if you want to enable rotation:
  # rotation_period = "7776000s"  # 90 days
  # next_rotation_time = "2026-01-01T00:00:00Z"

  lifecycle {
    prevent_destroy = true
  }
}

# ==============================================================================
# 3. Create GCS Bucket with CMEK
# ==============================================================================

resource "google_storage_bucket" "gemini_data_bucket" {
  name          = var.bucket_name
  location      = var.location
  storage_class = var.bucket_storage_class
  project       = var.project_id

  uniform_bucket_level_access = true

  encryption {
    default_kms_key_name = google_kms_crypto_key.gemini_key.id
  }

  depends_on = [
    google_kms_crypto_key_iam_member.gcs_service_agent,
  ]
}

# ==============================================================================
# 4. Grant IAM Permissions
# ==============================================================================

# Grant GCS Service Agent access to the KMS key
resource "google_kms_crypto_key_iam_member" "gcs_service_agent" {
  crypto_key_id = google_kms_crypto_key.gemini_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gs-project-accounts.iam.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# Grant Discovery Engine Service Agent access to the KMS key
resource "google_kms_crypto_key_iam_member" "discovery_engine_service_agent" {
  crypto_key_id = google_kms_crypto_key.gemini_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# Grant Discovery Engine Service Agent storage object viewer permissions
resource "google_project_iam_member" "discovery_engine_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# Grant Discovery Engine Service Agent storage admin permissions 
# (Only needed for logs created in a new bucket)
resource "google_project_iam_member" "discovery_engine_storage_admin" {
  count   = var.grant_ge_sa_storage_admin ? 1 : 0
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

resource "time_sleep" "wait_for_iam_permissions" {
  create_duration = "5s"

  depends_on = [
    google_kms_crypto_key_iam_member.discovery_engine_service_agent,
    google_project_iam_member.discovery_engine_storage_viewer,
    google_project_iam_member.discovery_engine_storage_admin
  ]
}

# ==============================================================================
# 5. Register CMEK with Discovery Engine (Gemini Enterprise)
# ==============================================================================

# Wait for CMEK configuration to propagate
# This should be ~15 minutes, set to shorter during testing
# If you don't wait you may get the following error:
###
# "detail": "[ORIGINAL ERROR] generic::failed_precondition: The location-level TP for `projects/48085522650/locations/us` is not READY; current state is INITIALIZING."
###
resource "time_sleep" "wait_for_cmek_initialization" {
  create_duration = "1200s"
  depends_on = [time_sleep.wait_for_iam_permissions]
}

resource "google_discovery_engine_cmek_config" "default" {
  location       = var.location
  cmek_config_id = var.cmek_config_id
  kms_key        = google_kms_crypto_key.gemini_key.id

  depends_on = [
    time_sleep.wait_for_cmek_initialization
  ]
}

# Wait for CMEK configuration to propagate
resource "time_sleep" "wait_for_cmek_config_propagation" {
  depends_on = [google_discovery_engine_cmek_config.default]
  create_duration = "30s"
}

# Verification: Retrieve the CMEK config (optional, for validation)
resource "null_resource" "verify_cmek_config" {
  triggers = {
    cmek_config_id = google_discovery_engine_cmek_config.default.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Verifying CMEK configuration..."
      curl -X GET \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        "https://${var.location}-discoveryengine.googleapis.com/v1/projects/${var.project_id}/locations/${var.location}/cmekConfigs/${var.cmek_config_id}"
    EOT
  }

  depends_on = [time_sleep.wait_for_cmek_config_propagation]
}

# ==============================================================================
# 6. Create Discovery Engine Data Store (Optional)
# ==============================================================================

# Note: Creating the data store is optional and disabled by default.
# Set var.create_data_store = true if you want to create it via Terraform.
# You may prefer to create it manually after waiting 15 minutes post-CMEK registration.

resource "google_discovery_engine_data_connector" "gcs_cmek" {
  count = var.create_data_store ? 1 : 0
  project                     = var.project_id
  location                    = var.data_store_location
  collection_id               = var.collection_id
  collection_display_name     = var.collection_display_name
  data_source                 = "gcs"
  refresh_interval            = "86400s"
  entities {
    entity_name               = "gcs_store"
    params = jsonencode({
      "content_config": "content_required"
      "auto_generate_ids": true
      "industry_vertical": "generic"
    })
  }
  json_params = jsonencode({
    "instance_uris": [
      "gs://${google_storage_bucket.gemini_data_bucket.name}/**"
    ]
  })
  kms_key_name = google_kms_crypto_key.gemini_key.id
  connector_modes              = ["DATA_INGESTION"]
  
  depends_on = [time_sleep.wait_for_cmek_config_propagation]
}

resource "time_sleep" "wait_for_data_connector" {
  create_duration = "5s"
  depends_on = [google_discovery_engine_data_connector.gcs_cmek]
}

# Import documents from GCS after data connector is created
resource "null_resource" "import_documents" {
  count = var.create_data_store ? 1 : 0

  triggers = {
    data_connector_id = google_discovery_engine_data_connector.gcs_cmek[0].id
    bucket_name       = google_storage_bucket.gemini_data_bucket.name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Importing documents from GCS to Discovery Engine..."
      curl -X POST \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        -H "Content-Type: application/json" \
        -H "X-Goog-User-Project: ${var.project_id}" \
        "https://${var.data_store_location}-discoveryengine.googleapis.com/v1/projects/${var.project_id}/locations/${var.data_store_location}/collections/${var.collection_id}/dataStores/${var.collection_id}_gcs_store/branches/0/documents:import" \
        -d '{
          "gcsSource": {
            "inputUris": ["gs://${google_storage_bucket.gemini_data_bucket.name}/**"],
            "dataSchema": "content"
          },
          "reconciliationMode": "FULL"
        }'
      echo ""
      echo "Document import operation initiated. Check Discovery Engine console for status."
    EOT
  }

  depends_on = [time_sleep.wait_for_data_connector]
}

# ==============================================================================
# 7. Create Gemini Enterprise Engine (Optional)
# ==============================================================================

# Note: Creating the search engine is optional and disabled by default.
# Set var.create_gemini_enterprise_engine = true if you want to create them via Terraform.
# Ensure CMEK configuration has propagated (wait 15 minutes) before creating these resources.
resource "google_discovery_engine_search_engine" "gemini_enterprise_basic" {
  count = var.create_gemini_enterprise_engine ? 1 : 0
  project        = var.project_id

  engine_id      = var.search_engine_id
  collection_id  = "default_collection"
  location       = var.data_store_location
  display_name   = var.search_engine_display_name

  # Connect data store ids to this engine. The data store ids from data connectors are
  # are formated as [collection_id]_[entity]. For example, the collection id of the 
  # connector above is connector-id-1, the resulting data_store_id would be 
  # connector-id-1_file for the file entity.

  # For GCS, need to append `_gcs_store` to the collection_id
  data_store_ids = [
    format("%s_gcs_store", google_discovery_engine_data_connector.gcs_cmek[0].collection_id)
  ]
  industry_vertical = "GENERIC"
  app_type          = "APP_TYPE_INTRANET"

  search_engine_config {
  }

  depends_on = [time_sleep.wait_for_data_connector]
}
