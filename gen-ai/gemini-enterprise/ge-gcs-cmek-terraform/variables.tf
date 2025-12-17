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

variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "location" {
  description = "Multi-Region location for KMS and GCS. Must be 'us' or 'eu' for Gemini Enterprise CMEK"
  type        = string
  default     = "us"

  validation {
    condition     = contains(["us", "eu"], var.location)
    error_message = "Location must be 'us' or 'eu' for Gemini Enterprise CMEK support."
  }
}

variable "key_ring_name" {
  description = "Name of the Cloud KMS key ring"
  type        = string
  default     = "gemini-enterprise-keyring"
}

variable "key_name" {
  description = "Name of the Cloud KMS crypto key"
  type        = string
  default     = "gemini-search-key"
}

variable "bucket_name" {
  description = "Name of the GCS bucket for Gemini data (must be globally unique)"
  type        = string
}

variable "bucket_storage_class" {
  description = "Storage class for the GCS bucket"
  type        = string
  default     = "STANDARD"
}

variable "collection_id" {
  description = "ID for the Discovery Engine collection"
  type        = string
  default     = "tf-collection-id"
}

variable "collection_display_name" {
  description = "Display name for the Discovery Engine collection"
  type        = string
  default     = "tf-collection-id"
}

variable "create_data_store" {
  description = "Whether to create the Discovery Engine data store via API (set to false if you want to create it manually later)"
  type        = bool
  default     = false
}

variable "create_gemini_enterprise_engine" {
  description = "Whether to create the Discovery Engine data store and search engine (set to false if you want to create it manually later)"
  type        = bool
  default     = false
}

variable "enable_apis" {
  description = "Whether to enable required Google Cloud APIs"
  type        = bool
  default     = true
}

variable "cmek_config_id" {
  description = "ID for the Discovery Engine CMEK configuration"
  type        = string
  default     = "default_cmek_config"
}

variable "data_store_id" {
  description = "ID for the Discovery Engine data store"
  type        = string
  default     = "tf-datastore-id"
}

variable "data_store_display_name" {
  description = "Display name for the Discovery Engine data store"
  type        = string
  default     = "tf-datastore-id"
}

variable "data_store_location" {
  description = "Location for the Discovery Engine data store (typically 'global')"
  type        = string
  default     = "us"
}

variable "search_engine_id" {
  description = "ID for the Discovery Engine search engine"
  type        = string
  default     = "tf-test-engine"
}

variable "search_engine_display_name" {
  description = "Display name for the Discovery Engine search engine"
  type        = string
  default     = "tf-test-engine"
}

