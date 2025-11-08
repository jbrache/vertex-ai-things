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

# Configure Terraform and required providers
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Configure the Google Cloud Provider for networking project (Shared VPC host)
provider "google" {
  project = var.networking_project_id
  region  = var.regions[0]  # Use first region as default
}

# Data source to get networking project number
data "google_project" "networking_project" {
  project_id = var.networking_project_id
}

# Data source to get project numbers for all Vertex AI service projects
data "google_project" "vertex_ai_service_projects" {
  for_each   = toset(var.vertex_ai_service_project_ids)
  project_id = each.value
}

# Enable required APIs in the networking project
resource "google_project_service" "networking_compute_api" {
  project = var.networking_project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "networking_dns_api" {
  project = var.networking_project_id
  service = "dns.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "networking_aiplatform_api" {
  project = var.networking_project_id
  service = "aiplatform.googleapis.com"

  disable_on_destroy = false
}

# Enable required APIs in all Vertex AI service projects
resource "google_project_service" "service_compute_api" {
  for_each = toset(var.vertex_ai_service_project_ids)

  project = each.value
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "service_aiplatform_api" {
  for_each = toset(var.vertex_ai_service_project_ids)

  project = each.value
  service = "aiplatform.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "service_artifactregistry_api" {
  for_each = var.create_vertex_test_container ? toset(var.vertex_ai_service_project_ids) : []

  project = each.value
  service = "artifactregistry.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "service_cloudbuild_api" {
  for_each = var.create_vertex_test_container ? toset(var.vertex_ai_service_project_ids) : []

  project = each.value
  service = "cloudbuild.googleapis.com"

  disable_on_destroy = false
}

# Wait 5 minutes after enabling Vertex AI API in networking project
# This allows time for the service agents to be properly provisioned
resource "time_sleep" "wait_for_networking_aiplatform_api" {
  depends_on = [google_project_service.networking_aiplatform_api]

  create_duration = "300s"  # 5 minutes
}

# Wait 5 minutes after enabling Vertex AI API in service projects
# This allows time for the service agents to be properly provisioned
resource "time_sleep" "wait_for_service_aiplatform_api" {
  depends_on = [google_project_service.service_aiplatform_api]

  create_duration = "300s"  # 5 minutes
}

# Create Artifact Registry repositories in each Vertex AI service project
resource "google_artifact_registry_repository" "vertex_training_repositories" {
  for_each = var.create_vertex_test_container ? toset(var.vertex_ai_service_project_ids) : []

  project       = each.value
  location      = var.artifact_registry_location
  repository_id = var.artifact_registry_repository_id
  description   = var.artifact_registry_description
  format        = var.artifact_registry_format

  depends_on = [
    google_project_service.service_artifactregistry_api
  ]
}

# Grant Cloud Build Builder role to Compute Engine default service account
resource "google_project_iam_member" "compute_engine_cloudbuild_builder" {
  for_each = var.create_vertex_test_container ? toset(var.vertex_ai_service_project_ids) : []

  project = each.value
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${data.google_project.vertex_ai_service_projects[each.value].number}-compute@developer.gserviceaccount.com"

  depends_on = [
    google_project_service.service_cloudbuild_api
  ]
}

# Automatically build and push the container when Terraform is applied
resource "null_resource" "build_vertex_training_container" {
  for_each = var.create_vertex_test_container ? toset(var.vertex_ai_service_project_ids) : []

  # Trigger rebuild when configuration changes
  triggers = {
    artifact_registry_location = var.artifact_registry_location
    artifact_registry_repo     = var.artifact_registry_repository_id
    # Uncomment to force rebuild on every apply:
    # timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud builds submit ${path.module}/test_container \
        --project=${each.value} \
        --config=${path.module}/test_container/cloudbuild.yaml \
        --substitutions=_ARTIFACT_REGISTRY_LOCATION=${var.artifact_registry_location},_ARTIFACT_REGISTRY_REPO=${var.artifact_registry_repository_id},_IMAGE_NAME=test,_IMAGE_TAG=latest
    EOT
  }

  depends_on = [
    google_project_service.service_cloudbuild_api,
    google_artifact_registry_repository.vertex_training_repositories
  ]
}

# Step 1: Create a VPC network in the networking project (Shared VPC host)
resource "google_compute_network" "vpc_network" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.networking_project_id
  description             = "Shared VPC network for Private Service Connect Interface to Vertex AI"

  depends_on = [
    google_project_service.networking_compute_api,
    google_project_service.networking_dns_api,
    time_sleep.wait_for_networking_aiplatform_api
  ]
}

# Step 2: Create subnets in each region in the networking project
# Generates a CIDR range automatically if not provided in subnet_cidr_ranges
locals {
  # Create a map of region to CIDR, using provided values or generating defaults
  region_cidrs = {
    for idx, region in var.regions :
    region => lookup(var.subnet_cidr_ranges, region, "10.${idx}.0.0/24")
  }
}

resource "google_compute_subnetwork" "subnets" {
  for_each = toset(var.regions)

  name          = "${each.value}-${var.subnet_name_postfix}"
  ip_cidr_range = local.region_cidrs[each.value]
  region        = each.value
  network       = google_compute_network.vpc_network.id
  project       = var.networking_project_id
  description   = "Subnet for Private Service Connect Interface to Vertex AI in ${each.value}"
}

# Step 2.5: Enable Shared VPC on the host project (optional)
resource "google_compute_shared_vpc_host_project" "host" {
  count   = var.enable_shared_vpc ? 1 : 0
  project = var.networking_project_id

  depends_on = [
    google_compute_network.vpc_network,
    google_project_service.networking_compute_api
  ]
}

# Step 2.6: Attach service projects to the Shared VPC (optional)
resource "google_compute_shared_vpc_service_project" "service_projects" {
  for_each = var.enable_shared_vpc ? toset(var.vertex_ai_service_project_ids) : []

  host_project    = var.networking_project_id
  service_project = each.value

  depends_on = [
    google_compute_shared_vpc_host_project.host,
    google_project_service.service_compute_api,
    time_sleep.wait_for_service_aiplatform_api
  ]
}

# Step 3: Create network attachments in each region in the networking project (VPC Host Project Network Attachment Mode only)
# When enable_shared_vpc = false, network attachments are created in the networking project
resource "google_compute_network_attachment" "psc_attachments" {
  for_each = var.enable_shared_vpc ? toset([]) : toset(var.regions)

  name        = "${each.value}-${var.network_attachment_name_postfix}"
  region      = each.value
  project     = var.networking_project_id
  description = "Network attachment for Private Service Connect Interface to Vertex AI in ${each.value} (VPC Host Project Network Attachment Mode)"

  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.subnets[each.value].self_link]

  depends_on = [
    google_compute_subnetwork.subnets
  ]
}

# Step 3.5: Create network attachments in each region for service projects (Service Project Network Attachment Mode only)
# When enable_shared_vpc = true, network attachments are created in each Vertex AI service project for each region
locals {
  # Create a set of all combinations of service projects and regions for Service Project Network Attachment Mode
  service_project_regions = var.enable_shared_vpc ? flatten([
    for project_id in var.vertex_ai_service_project_ids : [
      for region in var.regions : {
        project_id = project_id
        region     = region
        key        = "${project_id}-${region}"
      }
    ]
  ]) : []
}

resource "google_compute_network_attachment" "psc_attachments_service_projects" {
  for_each = {
    for item in local.service_project_regions :
    item.key => item
  }

  name        = "${each.value.region}-${var.network_attachment_name_postfix}"
  region      = each.value.region
  project     = each.value.project_id
  description = "Network attachment for Private Service Connect Interface to Vertex AI in ${each.value.region} (Service Project Network Attachment Mode)"

  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.subnets[each.value.region].self_link]

  depends_on = [
    google_compute_subnetwork.subnets,
    google_compute_shared_vpc_service_project.service_projects
  ]
}

# Step 3.6: Grant compute.networkUser role to service project Vertex AI service agents on the host project
# Required when network attachments are created in service projects (Service Project Network Attachment Mode)
# Reference: https://cloud.google.com/vertex-ai/docs/general/private-service-connect#shared-vpc
resource "google_project_iam_member" "service_vertex_ai_network_user_host" {
  for_each = var.enable_shared_vpc ? toset(var.vertex_ai_service_project_ids) : []

  project = var.networking_project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-${data.google_project.vertex_ai_service_projects[each.value].number}@gcp-sa-aiplatform.iam.gserviceaccount.com"

  depends_on = [
    google_compute_network_attachment.psc_attachments_service_projects,
    google_compute_shared_vpc_service_project.service_projects
  ]
}

# Step 4: Grant compute.networkAdmin role to the appropriate Vertex AI service agent
# In VPC Host Project Network Attachment Mode, grant the role to the networking project's service agent.
resource "google_project_iam_member" "networking_vertex_ai_network_admin_host_mode" {
  count   = var.enable_shared_vpc ? 0 : 1
  project = var.networking_project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:service-${data.google_project.networking_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"

  depends_on = [
    google_compute_network_attachment.psc_attachments,
    time_sleep.wait_for_networking_aiplatform_api
  ]
}

# In Service Project Network Attachment Mode, grant the role to each service project's own service agent.
resource "google_project_iam_member" "networking_vertex_ai_network_admin_service_mode" {
  for_each = var.enable_shared_vpc ? toset(var.vertex_ai_service_project_ids) : []

  project = each.key
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:service-${data.google_project.vertex_ai_service_projects[each.key].number}@gcp-sa-aiplatform.iam.gserviceaccount.com"

  depends_on = [
    google_compute_network_attachment.psc_attachments_service_projects,
    time_sleep.wait_for_service_aiplatform_api
  ]
}

# Step 4.5: Grant compute.networkUser role to Vertex AI service agents on each subnet (optional)
# This is required for Service Project Network Attachment to allow service projects to use the network
locals {
  # Create combinations of service projects and regions for subnet IAM
  subnet_iam_members = var.enable_shared_vpc ? flatten([
    for project_id in var.vertex_ai_service_project_ids : [
      for region in var.regions : {
        project_id = project_id
        region     = region
        key        = "${project_id}-${region}"
      }
    ]
  ]) : []
}

resource "google_compute_subnetwork_iam_member" "vertex_ai_network_user" {
  for_each = {
    for item in local.subnet_iam_members :
    item.key => item
  }

  project    = var.networking_project_id
  region     = each.value.region
  subnetwork = google_compute_subnetwork.subnets[each.value.region].name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.vertex_ai_service_projects[each.value.project_id].number}@gcp-sa-aiplatform.iam.gserviceaccount.com"

  depends_on = [google_compute_shared_vpc_service_project.service_projects]
}

# Step 5: Create firewall rule that allows SSH access on TCP port 22 in the networking project
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.network_name}-firewall-ssh"
  network = google_compute_network.vpc_network.name
  project = var.networking_project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  description   = "Allow SSH access on TCP port 22"
}

# Step 6: Create firewall rule that allows HTTPS traffic on TCP port 443 in the networking project
resource "google_compute_firewall" "allow_https" {
  name    = "${var.network_name}-firewall-https"
  network = google_compute_network.vpc_network.name
  project = var.networking_project_id

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = var.https_source_ranges
  description   = "Allow HTTPS traffic on TCP port 443"
}

# Step 7: Create firewall rule that allows ICMP traffic (ping requests) in the networking project
resource "google_compute_firewall" "allow_icmp" {
  name    = "${var.network_name}-firewall-icmp"
  network = google_compute_network.vpc_network.name
  project = var.networking_project_id

  allow {
    protocol = "icmp"
  }

  source_ranges = var.icmp_source_ranges
  description   = "Allow ICMP traffic (ping requests)"
}

# Step 8: Assign DNS Peer role to service projects' Vertex AI service agents in the networking project (host)
resource "google_project_iam_member" "service_dns_peer" {
  for_each = toset(var.vertex_ai_service_project_ids)
  
  project = var.networking_project_id
  role    = "roles/dns.peer"
  member  = "serviceAccount:service-${data.google_project.vertex_ai_service_projects[each.value].number}@gcp-sa-aiplatform.iam.gserviceaccount.com"

  depends_on = [
    google_compute_network_attachment.psc_attachments,
    google_compute_network_attachment.psc_attachments_service_projects,
    time_sleep.wait_for_service_aiplatform_api
  ]
}

# Step 9: Create firewall rule that allows all ICMP, TCP, and UDP traffic (optional)
# Uncomment if you need to allow all internal traffic
resource "google_compute_firewall" "allow_all_internal" {
  count   = var.enable_allow_all_firewall ? 1 : 0
  name    = "${var.network_name}-firewall-all-internal"
  network = google_compute_network.vpc_network.name
  project = var.networking_project_id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = var.all_traffic_source_ranges
  description   = "Allow all ICMP, TCP, and UDP traffic from specified ranges"
}
