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

# Subnet Outputs (Multi-region)
output "subnets" {
  description = "Map of region names to subnet details"
  value = {
    for region in var.regions :
    region => {
      name          = google_compute_subnetwork.subnets[region].name
      id            = google_compute_subnetwork.subnets[region].id
      self_link     = google_compute_subnetwork.subnets[region].self_link
      ip_cidr_range = google_compute_subnetwork.subnets[region].ip_cidr_range
    }
  }
}

# Network Attachment Outputs - VPC Host Project Network Attachment Mode (Multi-region)
output "network_attachments_standalone" {
  description = "Map of region names to network attachment details (VPC Host Project Network Attachment Mode only)"
  value = var.enable_shared_vpc ? null : {
    for region in var.regions :
    region => {
      name                  = google_compute_network_attachment.psc_attachments[region].name
      id                    = google_compute_network_attachment.psc_attachments[region].id
      self_link             = google_compute_network_attachment.psc_attachments[region].self_link
      connection_preference = google_compute_network_attachment.psc_attachments[region].connection_preference
    }
  }
}

# Network Attachment Outputs - Service Project Network Attachment Mode (Multi-region)
output "network_attachments_service_projects" {
  description = "Nested map of service project IDs and regions to network attachment self-links (Service Project Network Attachment Mode only)"
  value = var.enable_shared_vpc ? {
    for project_id in var.vertex_ai_service_project_ids :
    project_id => {
      for region in var.regions :
      region => google_compute_network_attachment.psc_attachments_service_projects["${project_id}-${region}"].self_link
    }
  } : null
}

output "network_attachments_details" {
  description = "Detailed information about network attachments in each service project and region (Shared VPC mode only)"
  value = var.enable_shared_vpc ? {
    for project_id in var.vertex_ai_service_project_ids :
    project_id => {
      for region in var.regions :
      region => {
        name      = google_compute_network_attachment.psc_attachments_service_projects["${project_id}-${region}"].name
        id        = google_compute_network_attachment.psc_attachments_service_projects["${project_id}-${region}"].id
        self_link = google_compute_network_attachment.psc_attachments_service_projects["${project_id}-${region}"].self_link
        project   = google_compute_network_attachment.psc_attachments_service_projects["${project_id}-${region}"].project
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

output "vertex_ai_service_project_ids" {
  description = "List of Vertex AI service project IDs attached to the Shared VPC"
  value       = var.vertex_ai_service_project_ids
}

output "vertex_ai_service_project_numbers" {
  description = "Map of Vertex AI service project IDs to their project numbers"
  value = {
    for project_id in var.vertex_ai_service_project_ids :
    project_id => data.google_project.vertex_ai_service_projects[project_id].number
  }
}

output "regions" {
  description = "The list of regions where resources were created"
  value       = var.regions
}

# Service Account Information
output "vertex_ai_service_agents" {
  description = "Map of Vertex AI service project IDs to their service agent emails"
  value = {
    for project_id in var.vertex_ai_service_project_ids :
    project_id => "service-${data.google_project.vertex_ai_service_projects[project_id].number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
  }
}

# Firewall Rules
output "firewall_rules" {
  description = "List of firewall rules created"
  value = {
    ssh   = google_compute_firewall.allow_ssh.name
    https = google_compute_firewall.allow_https.name
    icmp  = google_compute_firewall.allow_icmp.name
    all   = var.enable_allow_all_firewall ? google_compute_firewall.allow_all_internal[0].name : "not_created"
  }
}

# Shared VPC Configuration
output "shared_vpc_host_project" {
  description = "The Shared VPC host project ID"
  value       = var.networking_project_id
}

output "shared_vpc_service_projects" {
  description = "List of service projects attached to the Shared VPC"
  value       = var.vertex_ai_service_project_ids
}

# Artifact Registry and Container Build Outputs
output "artifact_registry_repositories" {
  description = "Map of Vertex AI service project IDs to their Artifact Registry repository details"
  value = var.create_vertex_test_container ? {
    for project_id in var.vertex_ai_service_project_ids :
    project_id => {
      repository_id = google_artifact_registry_repository.vertex_training_repositories[project_id].repository_id
      location      = google_artifact_registry_repository.vertex_training_repositories[project_id].location
      format        = google_artifact_registry_repository.vertex_training_repositories[project_id].format
      name          = google_artifact_registry_repository.vertex_training_repositories[project_id].name
      registry_uri  = "${google_artifact_registry_repository.vertex_training_repositories[project_id].location}-docker.pkg.dev/${project_id}/${google_artifact_registry_repository.vertex_training_repositories[project_id].repository_id}"
    }
  } : null
}

output "container_images" {
  description = "Map of Vertex AI service project IDs to their built container image URIs"
  value = var.create_vertex_test_container ? {
    for project_id in var.vertex_ai_service_project_ids :
    project_id => {
      latest      = "${google_artifact_registry_repository.vertex_training_repositories[project_id].location}-docker.pkg.dev/${project_id}/${google_artifact_registry_repository.vertex_training_repositories[project_id].repository_id}/test:latest"
    }
  } : null
}

output "cloud_build_enabled" {
  description = "Indicates whether Cloud Build API has been enabled in service projects"
  value       = var.create_vertex_test_container
}

# Proxy VM and Network Infrastructure Outputs
output "proxy_vm" {
  description = "Proxy VM details (when created)"
  value = var.create_proxy_vm ? {
    name         = google_compute_instance.proxy_vm[0].name
    zone         = google_compute_instance.proxy_vm[0].zone
    machine_type = google_compute_instance.proxy_vm[0].machine_type
    internal_ip  = google_compute_instance.proxy_vm[0].network_interface[0].network_ip
    self_link    = google_compute_instance.proxy_vm[0].self_link
  } : null
}

output "cloud_router" {
  description = "Cloud Router details (when proxy VM is created)"
  value = var.create_proxy_vm ? {
    name      = google_compute_router.router[0].name
    region    = google_compute_router.router[0].region
    self_link = google_compute_router.router[0].self_link
  } : null
}

output "cloud_nat" {
  description = "Cloud NAT details (when proxy VM is created)"
  value = var.create_proxy_vm ? {
    name      = google_compute_router_nat.nat[0].name
    region    = google_compute_router_nat.nat[0].region
    router    = google_compute_router_nat.nat[0].router
  } : null
}

# DNS Configuration Outputs
output "dns_zone" {
  description = "Private DNS zone details (when created)"
  value = var.create_dns_zone ? {
    name        = google_dns_managed_zone.private_zone[0].name
    dns_name    = google_dns_managed_zone.private_zone[0].dns_name
    description = google_dns_managed_zone.private_zone[0].description
    name_servers = google_dns_managed_zone.private_zone[0].name_servers
  } : null
}

output "dns_proxy_vm_record" {
  description = "DNS A record for the proxy VM (when created)"
  value = (var.create_dns_zone && var.create_proxy_vm) ? {
    name    = google_dns_record_set.proxy_vm_record[0].name
    type    = google_dns_record_set.proxy_vm_record[0].type
    ttl     = google_dns_record_set.proxy_vm_record[0].ttl
    rrdatas = google_dns_record_set.proxy_vm_record[0].rrdatas
  } : null
}

# API Services Enabled
output "enabled_apis" {
  description = "Map of enabled APIs in networking and service projects"
  value = {
    networking_project = local.networking_apis
    service_projects   = local.service_apis
  }
}

# Usage Instructions
output "vertex_ai_usage_instructions" {
  description = "Instructions for using the network attachments with Vertex AI"
  value = var.enable_shared_vpc ? join("\n", [
    "========================================",
    "Service Project Network Attachment Mode - Private Service Connect Configuration (Multi-Region)",
    "========================================",
    "",
    "Network Configuration:",
    "- Deployment Mode: Service Project Network Attachment",
    "- Networking Project (Host): ${var.networking_project_id}",
    "- Service Projects: ${join(", ", var.vertex_ai_service_project_ids)}",
    "- Regions: ${join(", ", var.regions)}",
    "- Network Attachments: Created in each service project for each region",
    "",
    "========================================",
    "Usage Instructions (Service Project Network Attachment Mode)",
    "========================================",
    "",
    "In Shared VPC mode, each service project has network attachments in each configured region.",
    "When creating Vertex AI resources, use the network attachment from the same project and region.",
    "",
    "Network Attachment Self-Links by Service Project and Region:",
    join("\n", flatten([
      for project_id in var.vertex_ai_service_project_ids : [
        "Project: ${project_id}",
        [for region in var.regions : "  - ${region}: ${google_compute_network_attachment.psc_attachments_service_projects["${project_id}-${region}"].self_link}"]
      ]
    ])),
    "",
    "Example for creating a custom training job:",
    "gcloud ai custom-jobs create \\",
    "  --project=<SERVICE_PROJECT_ID> \\",
    "  --region=<REGION> \\",
    "  --display-name=my-training-job \\",
    "  --network-attachment=<NETWORK_ATTACHMENT_FROM_SAME_PROJECT_AND_REGION> \\",
    "  --config=job_config.yaml",
    "",
    "IAM Permissions Granted:",
    "The following roles have been granted for each service project's Vertex AI service agent:",
    "",
    "In the networking project (${var.networking_project_id}):",
    "- roles/compute.networkAdmin (project-level) - For networking project's own service agent",
    "- roles/compute.networkUser (project-level) - For each service project's service agent",
    "- roles/compute.networkUser (subnet-level in each region) - For each service project's service agent",
    "- roles/dns.peer (project-level) - For each service project's service agent",
    "",
    "Service Agents Configured:",
    join("\n", [for project_id in var.vertex_ai_service_project_ids : "- Project: ${project_id}\n  Service Agent: service-${data.google_project.vertex_ai_service_projects[project_id].number}@gcp-sa-aiplatform.iam.gserviceaccount.com"]),
  ]) : join("\n", [
    "========================================",
    "VPC Host Project Network Attachment Mode - Private Service Connect Configuration (Multi-Region)",
    "========================================",
    "",
    "Network Configuration:",
    "- Deployment Mode: VPC Host Project Network Attachment",
    "- Networking Project: ${var.networking_project_id}",
    "- Service Projects: ${join(", ", var.vertex_ai_service_project_ids)}",
    "- Regions: ${join(", ", var.regions)}",
    "",
    "Network Attachment Self-Links by Region:",
    join("\n", [for region in var.regions : "- ${region}: ${google_compute_network_attachment.psc_attachments[region].self_link}"]),
    "",
    "========================================",
    "Usage Instructions (VPC Host Project Network Attachment Mode)",
    "========================================",
    "",
    "When creating Vertex AI resources from any service project, specify the network attachment",
    "for the appropriate region where you want to run the workload.",
    "",
    "Example for creating a custom training job:",
    "gcloud ai custom-jobs create \\",
    "  --project=<YOUR_SERVICE_PROJECT_ID> \\",
    "  --region=<REGION> \\",
    "  --display-name=my-training-job \\",
    "  --network-attachment=<NETWORK_ATTACHMENT_FOR_SAME_REGION> \\",
    "  --config=job_config.yaml",
    "",
    "IAM Permissions Granted:",
    "The following roles have been granted in the networking project (${var.networking_project_id}):",
    "- roles/compute.networkAdmin (project-level) - For networking project's Vertex AI service agent",
    "- roles/dns.peer (project-level) - For each service project's Vertex AI service agent",
    "",
    "Service Agents Configured:",
    join("\n", [for project_id in var.vertex_ai_service_project_ids : "- Project: ${project_id}\n  Service Agent: service-${data.google_project.vertex_ai_service_projects[project_id].number}@gcp-sa-aiplatform.iam.gserviceaccount.com"]),
  ])
}
