# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Terraform Variables Configuration for Vertex AI Private Service Connect Interface
# Copy this file and customize the values for your deployment

# ============================================
# REQUIRED: Project and Region Configuration
# ============================================
# The networking project (Shared VPC host project) where VPC resources will be created
networking_project_id = "YOUR_NETWORKING_PROJECT_ID"

# List of Vertex AI service projects that will use the Shared VPC
# Add all project IDs where Vertex AI workloads will run
vertex_ai_service_project_ids = [
  "YOUR_VERTEX_AI_PROJECT_1",
  "YOUR_VERTEX_AI_PROJECT_2"
  # Add more project IDs as needed
]

# List of regions where subnets and network attachments will be created
# You can specify multiple regions for multi-region deployment
regions = ["us-central1"]
# regions = ["us-central1", "us-west1"]

# Optional: Specify custom CIDR ranges for each region
# If not specified, default ranges will be automatically generated (10.0.0.0/24, 10.1.0.0/24, etc.)
subnet_cidr_ranges = {
  "us-central1" = "10.0.0.0/24"
  # "us-west1"    = "10.1.0.0/24"
  # Add more regions and their CIDR ranges as needed
  # "europe-west1" = "10.2.0.0/24"
  # "asia-east1"   = "10.3.0.0/24"
}

# ============================================
# Network Configuration
# ============================================
network_name = "vertex-vpc-dev"

# Postfix for subnet names - region will be used as prefix (e.g., "us-central1-vertex-psci")
subnet_name_postfix = "vertex-psci"

# ============================================
# Network Attachment Configuration
# ============================================
# Postfix for network attachment names - region will be used as prefix (e.g., "us-central1-vertex-psci")
network_attachment_name_postfix = "vertex-psci"

# ============================================
# Firewall Configuration
# ============================================
# SSH access on TCP port 22
ssh_source_ranges = ["0.0.0.0/0"]  # Restrict this to your IP ranges for better security

# HTTPS traffic on TCP port 443
https_source_ranges = ["0.0.0.0/0"]

# ICMP traffic (ping)
icmp_source_ranges = ["0.0.0.0/0"]

# Optional: Enable firewall rule that allows all ICMP, TCP, and UDP traffic
enable_allow_all_firewall = false

# Source IP ranges for the optional allow-all firewall rule
# Only used if enable_allow_all_firewall is set to true
all_traffic_source_ranges = ["10.0.0.0/8"]

# ============================================
# Artifact Registry and Cloud Build Configuration
# ============================================
# Creates a container used for Vertex AI, using Artifact Registry and Cloud Build
create_vertex_test_container = true

# ============================================
# Vertex AI Custom Job Configuration
# ============================================
create_training_job = true

# ============================================
# Proxy VM Configuration
# ============================================
create_proxy_vm = false

# ============================================
# Cloud DNS Configuration
# ============================================
create_dns_zone = false
