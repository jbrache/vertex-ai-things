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

# Network Outputs
output "network_name" {
  description = "The name of the VPC network created"
  value       = google_compute_network.vpc_network.name
}

output "network_id" {
  description = "The ID of the VPC network created"
  value       = google_compute_network.vpc_network.id
}

output "network_self_link" {
  description = "The self-link of the VPC network created"
  value       = google_compute_network.vpc_network.self_link
}

# Subnet Outputs
output "subnet" {
  description = "Subnet details"
  value = {
    name          = google_compute_subnetwork.intf_subnet.name
    id            = google_compute_subnetwork.intf_subnet.id
    self_link     = google_compute_subnetwork.intf_subnet.self_link
    ip_cidr_range = google_compute_subnetwork.intf_subnet.ip_cidr_range
  }
}

# Network Attachment Outputs - VPC Host Project Network Attachment Mode
output "network_attachment_standalone" {
  description = "Network attachment details (VPC Host Project Network Attachment Mode only)"
  value = var.enable_shared_vpc ? null : {
    name                  = google_compute_network_attachment.psc_attachments[0].name
    id                    = google_compute_network_attachment.psc_attachments[0].id
    self_link             = google_compute_network_attachment.psc_attachments[0].self_link
    connection_preference = google_compute_network_attachment.psc_attachments[0].connection_preference
  }
}

# Network Attachment Outputs - Service Project Network Attachment Mode
output "network_attachments_service_projects" {
  description = "Nested map of service project IDs and regions to network attachment self-links (Service Project Network Attachment Mode only)"
  value = var.enable_shared_vpc ? {
    for project_id in [var.vertex_ai_service_project_id] :
    project_id => {
      for region in [var.region] :
      region => google_compute_network_attachment.psc_attachments_service_project[0].self_link
    }
  } : null
}

output "network_attachments_details" {
  description = "Detailed information about network attachments in each service project and region (Shared VPC mode only)"
  value = var.enable_shared_vpc ? {
    for project_id in [var.vertex_ai_service_project_id] :
    project_id => {
      for region in [var.region] :
      region => {
        name      = google_compute_network_attachment.psc_attachments_service_project[0].name
        id        = google_compute_network_attachment.psc_attachments_service_project[0].id
        self_link = google_compute_network_attachment.psc_attachments_service_project[0].self_link
        project   = google_compute_network_attachment.psc_attachments_service_project[0].project
      }
    }
  } : null
}

# Project Information
output "networking_project_id" {
  description = "The networking project ID (Shared VPC host) where network resources were created"
  value       = var.networking_project_id
}

output "networking_project_number" {
  description = "The networking project number"
  value       = data.google_project.networking_project.number
}

output "vertex_ai_service_project_id" {
  description = "The Vertex AI service project ID attached to the Shared VPC"
  value       = var.vertex_ai_service_project_id
}

output "vertex_ai_service_project_number" {
  description = "The Vertex AI service project number"
  value       = data.google_project.vertex_ai_service_project.number
}

output "region" {
  description = "The region where resources were created"
  value       = var.region
}

# Service Account Information
output "vertex_ai_service_agent" {
  description = "The Vertex AI service agent email"
  value       = "service-${data.google_project.vertex_ai_service_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
}

# Firewall Rules
output "firewall_rules" {
  description = "List of firewall rules created"
  value = {
    ssh   = google_compute_firewall.allow_ssh_iap.name
    https = google_compute_firewall.allow_access_to_proxy.name
    icmp  = google_compute_firewall.allow_access_to_class_e.name
    all   = var.enable_allow_all_firewall ? google_compute_firewall.allow_all_internal[0].name : "not_created"
  }
}

# Shared VPC Configuration
output "shared_vpc_host_project" {
  description = "The Shared VPC host project ID"
  value       = var.networking_project_id
}

output "shared_vpc_service_project" {
  description = "The service project attached to the Shared VPC"
  value       = var.vertex_ai_service_project_id
}

# Artifact Registry and Container Build Outputs
output "artifact_registry_repository" {
  description = "Artifact Registry repository details"
  value = var.create_vertex_test_container ? {
    repository_id = google_artifact_registry_repository.vertex_training_repositories[0].repository_id
    location      = google_artifact_registry_repository.vertex_training_repositories[0].location
    format        = google_artifact_registry_repository.vertex_training_repositories[0].format
    name          = google_artifact_registry_repository.vertex_training_repositories[0].name
    registry_uri  = "${google_artifact_registry_repository.vertex_training_repositories[0].location}-docker.pkg.dev/${var.vertex_ai_service_project_id}/${google_artifact_registry_repository.vertex_training_repositories[0].repository_id}"
  } : null
}

output "container_image" {
  description = "Built container image URI"
  value = var.create_vertex_test_container ? {
    latest      = "${google_artifact_registry_repository.vertex_training_repositories[0].location}-docker.pkg.dev/${var.vertex_ai_service_project_id}/${google_artifact_registry_repository.vertex_training_repositories[0].repository_id}/test:latest"
  } : null
}

output "cloud_build_enabled" {
  description = "Indicates whether Cloud Build API has been enabled in service projects"
  value       = var.create_vertex_test_container
}

# Usage Instructions
output "vertex_ai_usage_instructions" {
  description = "Instructions for using the network attachments with Vertex AI"
  value = var.enable_shared_vpc ? join("\n", [
    "========================================",
    "Service Project Network Attachment Mode - Private Service Connect Configuration",
    "========================================",
    "",
    "Network Configuration:",
    "- Deployment Mode: Service Project Network Attachment",
    "- Networking Project (Host): ${var.networking_project_id}",
    "- Service Project: ${var.vertex_ai_service_project_id}",
    "- Region: ${var.region}",
    "- Network Attachment: Created in the service project for the region",
    "",
    "========================================",
    "Usage Instructions (Service Project Network Attachment Mode)",
    "========================================",
    "",
    "In Shared VPC mode, the service project has a network attachment in the configured region.",
    "When creating Vertex AI resources, use the network attachment from the same project and region.",
    "",
    "Network Attachment Self-Link:",
    "  - ${var.region}: ${google_compute_network_attachment.psc_attachments_service_project[0].self_link}",
    "",
    "Example for creating a custom training job:",
    "gcloud ai custom-jobs create \\",
    "  --project=${var.vertex_ai_service_project_id} \\",
    "  --region=${var.region} \\",
    "  --display-name=my-training-job \\",
    "  --network-attachment=<NETWORK_ATTACHMENT_FROM_THE_PROJECT> \\",
    "  --config=job_config.yaml",
    "",
    "IAM Permissions Granted:",
    "The following roles have been granted for the Vertex AI service agent:",
    "",
    "In the networking project (${var.networking_project_id}):",
    "- roles/compute.networkAdmin (project-level) - For networking project's own service agent",
    "- roles/compute.networkUser (project-level) - For the service project's service agent",
    "- roles/compute.networkUser (subnet-level in the region) - For the service project's service agent",
    "- roles/dns.peer (project-level) - For the service project's service agent",
    "",
    "Service Agent Configured:",
    "Project: ${var.vertex_ai_service_project_id}\n  Service Agent: service-${data.google_project.vertex_ai_service_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com",
  ]) : join("\n", [
    "========================================",
    "VPC Host Project Network Attachment Mode - Private Service Connect Configuration",
    "========================================",
    "",
    "Network Configuration:",
    "- Deployment Mode: VPC Host Project Network Attachment",
    "- Networking Project: ${var.networking_project_id}",
    "- Service Project: ${var.vertex_ai_service_project_id}",
    "- Region: ${var.region}",
    "",
    "Network Attachment Self-Link:",
    google_compute_network_attachment.psc_attachments[0].self_link,
    "",
    "========================================",
    "Usage Instructions (VPC Host Project Network Attachment Mode)",
    "========================================",
    "",
    "When creating Vertex AI resources from the service project, specify the network attachment",
    "for the appropriate region where you want to run the workload.",
    "",
    "Example for creating a custom training job:",
    "gcloud ai custom-jobs create \\",
    "  --project=${var.vertex_ai_service_project_id} \\",
    "  --region=${var.region} \\",
    "  --display-name=my-training-job \\",
    "  --network-attachment=<NETWORK_ATTACHMENT_FOR_THE_REGION> \\",
    "  --config=job_config.yaml",
    "",
    "IAM Permissions Granted:",
    "The following roles have been granted in the networking project (${var.networking_project_id}):",
    "- roles/compute.networkAdmin (project-level) - For networking project's Vertex AI service agent",
    "- roles/dns.peer (project-level) - For the service project's Vertex AI service agent",
    "",
    "Service Agent Configured:",
    "Project: ${var.vertex_ai_service_project_id}\n  Service Agent: service-${data.google_project.vertex_ai_service_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com",
  ])
}
