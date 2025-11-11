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

# ============================================
# Project and Region Configuration
# ============================================
variable "networking_project_id" {
  description = "The Google Cloud project ID where networking resources (VPC, subnet, network attachment) will be created"
  type        = string
}

variable "vertex_ai_service_project_id" {
  description = "The Google Cloud project ID where Vertex AI services will run. The Vertex AI service agent from this project will be granted necessary permissions in the networking project."
  type        = string
}

variable "region" {
  description = "The region where resources will be created"
  type        = string
  default     = "us-central1"
}

# ============================================
# Network Configuration
# ============================================
variable "network_name" {
  description = "Name of the VPC network to create"
  type        = string
  default     = "consumer-vpc"
}

# ============================================
# Network Attachment Configuration
# ============================================
variable "network_attachment_name_postfix" {
  description = "Postfix for network attachment names. Region name will be used as prefix (e.g., 'us-central1-vertex-psci')"
  type        = string
  default     = "vertex-psci"
}

# ============================================
# Firewall Configuration
# ============================================
variable "enable_allow_all_firewall" {
  description = "Enable firewall rule to allow all internal traffic."
  type        = bool
  default     = false
}

variable "all_traffic_source_ranges" {
  description = "Source IP ranges for the optional allow-all firewall rule"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# ============================================
# Shared VPC Configuration
# ============================================
variable "enable_shared_vpc" {
  description = "Enable Service Project Network Attachment Mode. When true, sets up the networking project as a Shared VPC host and attaches service projects."
  type        = bool
  default     = false
}

# ============================================
# Vertex AI Custom Job Configuration
# ============================================
variable "create_training_job" {
  description = "If true, creates a Vertex AI custom training job in each service project using the created resources."
  type        = bool
  default     = true
}

# ============================================
# Artifact Registry Configuration
# ============================================
variable "create_vertex_test_container" {
  description = "Enable creation of Artifact Registry repository and Cloud Build API for Vertex AI training containers"
  type        = bool
  default     = true
}

variable "artifact_registry_repository_id" {
  description = "The ID of the Artifact Registry repository to create"
  type        = string
  default     = "pipelines-test-repo-psc"
}

variable "image_name" {
  description = "The name of the container image."
  type        = string
  default     = "nonrfc-ip-call"
}

variable "artifact_registry_location" {
  description = "The location for the Artifact Registry repository (e.g., 'us' for multi-region)"
  type        = string
  default     = "us"
}

variable "artifact_registry_description" {
  description = "Description for the Artifact Registry repository"
  type        = string
  default     = "Vertex AI training test repository"
}

variable "artifact_registry_format" {
  description = "The format of the Artifact Registry repository"
  type        = string
  default     = "DOCKER"
}

# ============================================
# Proxy VM and Class E VM Configuration
# ============================================
variable "create_nat_gateway" {
  description = "If true, creates a Cloud Router and a Cloud NAT gateway in the region."
  type        = bool
  default     = true
}

variable "create_proxy_vm" {
  description = "If true, creates a proxy VM in the region."
  type        = bool
  default     = true
}

variable "create_class_e_vm" {
  description = "If true, creates a class-e VM in the region."
  type        = bool
  default     = true
}

variable "vm_zone" {
  description = "The zone for the VMs. Should be in the region."
  type        = string
  default     = "us-central1-a"
}

variable "vm_machine_type" {
  description = "The machine type for the VMs."
  type        = string
  default     = "e2-micro"
}

# ============================================
# Cloud DNS Configuration
# ============================================
variable "create_dns_zone" {
  description = "If true, creates a private Cloud DNS zone and an A record for the proxy VM."
  type        = bool
  default     = true
}

variable "dns_zone_name" {
  description = "The name of the Cloud DNS managed zone."
  type        = string
  default     = "private-dns-codelab"
}

variable "dns_domain" {
  description = "The DNS name of the managed zone (e.g., 'demo.com.')."
  type        = string
  default     = "demo.com."
}
