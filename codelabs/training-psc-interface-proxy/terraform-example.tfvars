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
# networking_project_id = "YOUR_NETWORKING_PROJECT_ID"
networking_project_id = "codelab-dev-jb0001"

# Vertex AI service project that will use the Shared VPC
# Project ID where Vertex AI workloads will run
# vertex_ai_service_project_id = "YOUR_VERTEX_AI_PROJECT_1"
vertex_ai_service_project_id = "codelab-dev-jb0001"

# List of regions where subnets and network attachments will be created
# You can specify multiple regions for multi-region deployment
region = "us-central1"

# ============================================
# Network Configuration
# ============================================
network_name = "consumer-vpc"

# ============================================
# Network Attachment Configuration
# ============================================
# Postfix for network attachment names - region will be used as prefix (e.g., "us-central1-vertex-psci")
network_attachment_name_postfix = "vertex-psci"

# ============================================
# Firewall Configuration
# ============================================

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
# Proxy VM and Class E VM Configuration
# ============================================
create_proxy_vm = true
create_class_e_vm = true
create_nat_gateway = true

# ============================================
# Cloud DNS Configuration
# ============================================
create_dns_zone = true
