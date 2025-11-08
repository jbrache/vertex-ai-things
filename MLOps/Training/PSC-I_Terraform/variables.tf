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

# Project and Region Configuration
variable "networking_project_id" {
  description = "The Google Cloud project ID where networking resources (VPC, subnet, network attachment) will be created"
  type        = string
}

variable "vertex_ai_service_project_ids" {
  description = "List of Google Cloud project IDs where Vertex AI services will run. The Vertex AI service agents from these projects will be granted necessary permissions in the networking project."
  type        = list(string)
}

variable "regions" {
  description = "List of regions where subnets and network attachments will be created"
  type        = list(string)
  default     = ["us-central1"]
}

variable "subnet_cidr_ranges" {
  description = "Map of region names to subnet CIDR ranges. If not specified for a region, a default range will be used."
  type        = map(string)
  default     = {}
}

# Network Configuration
variable "network_name" {
  description = "Name of the VPC network to create"
  type        = string
  default     = "vertex-vpc-dev"
}

variable "subnet_name_postfix" {
  description = "Postfix for subnet names. Region name will be used as prefix (e.g., 'us-central1-vertex-psci')"
  type        = string
  default     = "vertex-psci"
}

# Network Attachment Configuration
variable "network_attachment_name_postfix" {
  description = "Postfix for network attachment names. Region name will be used as prefix (e.g., 'us-central1-vertex-psci')"
  type        = string
  default     = "vertex-psci"
}

# Firewall Configuration
variable "ssh_source_ranges" {
  description = "Source IP ranges allowed for SSH access (TCP port 22)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "https_source_ranges" {
  description = "Source IP ranges allowed for HTTPS traffic (TCP port 443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "icmp_source_ranges" {
  description = "Source IP ranges allowed for ICMP traffic (ping)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_allow_all_firewall" {
  description = "Enable firewall rule that allows all ICMP, TCP, and UDP traffic (optional)"
  type        = bool
  default     = false
}

variable "all_traffic_source_ranges" {
  description = "Source IP ranges for the optional allow-all firewall rule"
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

# Shared VPC Configuration
variable "enable_shared_vpc" {
  description = "Enable Service Project Network Attachment Mode. When true, sets up the networking project as a Shared VPC host and attaches service projects."
  type        = bool
  default     = false
}

# Artifact Registry Configuration
variable "create_vertex_test_container" {
  description = "Enable creation of Artifact Registry repository and Cloud Build API for Vertex AI training containers"
  type        = bool
  default     = true
}

variable "artifact_registry_repository_id" {
  description = "The ID of the Artifact Registry repository to create"
  type        = string
  default     = "vertex-training-test"
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
