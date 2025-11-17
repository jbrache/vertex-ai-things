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
# Configure Terraform and required providers
# ============================================
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

# ============================================
# Configure the Google Cloud Provider for networking project (VPC host project)
# ============================================
provider "google" {
  project = var.networking_project_id
  region  = var.regions[0]  # Use first region as default
}

# ============================================
# Data source to get networking project number
# ============================================
data "google_project" "networking_project" {
  project_id = var.networking_project_id
}

# Data source to get project numbers for all Vertex AI service projects
data "google_project" "vertex_ai_service_projects" {
  for_each   = toset(var.vertex_ai_service_project_ids)
  project_id = each.value
}

# ============================================
# Define API lists for each project
# ============================================
locals {
  # APIs always enabled in the networking project
  networking_base_apis = [
    "compute.googleapis.com",
    "dns.googleapis.com",
    "storage.googleapis.com"
  ]
  
  # Conditionally add aiplatform API to networking project (only in VPC Host Project Network Attachment Mode)
  networking_apis = var.enable_shared_vpc ? local.networking_base_apis : concat(local.networking_base_apis, ["aiplatform.googleapis.com"])
  
  # APIs always enabled in the service project
  service_base_apis = [
    "aiplatform.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com"
  ]
  
  # Conditionally add container-related APIs to service project
  service_apis = var.create_vertex_test_container ? concat(local.service_base_apis, ["artifactregistry.googleapis.com", "cloudbuild.googleapis.com"]) : local.service_base_apis
  
  # Create combinations of service projects and APIs for iteration
  service_project_api_combinations = flatten([
    for project_id in var.vertex_ai_service_project_ids : [
      for api in local.service_apis : {
        project_id = project_id
        api        = api
        key        = "${project_id}-${replace(api, ".", "-")}"
      }
    ]
  ])
}

# ============================================
# Enable required APIs in the networking project
# ============================================
# In the networking project
resource "google_project_service" "networking_project_apis" {
  for_each = toset(local.networking_apis)
  project = var.networking_project_id
  service = each.value
  disable_on_destroy = false
}

# In the Vertex AI service projects
resource "google_project_service" "service_project_apis" {
  for_each = {
    for item in local.service_project_api_combinations :
    item.key => item
  }
  
  project            = each.value.project_id
  service            = each.value.api
  disable_on_destroy = false
}

# Wait after enabling APIs
resource "time_sleep" "wait_for_project_apis" {
  depends_on = [
    google_project_service.networking_project_apis,
    google_project_service.service_project_apis
  ]
  create_duration = "5s"
}

# ============================================
# Configure Organization Policy for IP Forwarding of Proxy VM
# ============================================
resource "google_project_organization_policy" "ip_forward" {
  count   = var.create_proxy_vm ? 1 : 0
  project = var.networking_project_id
  constraint = "compute.vmCanIpForward"
  list_policy {
    allow {
      values = [
        "projects/${var.networking_project_id}/zones/${var.proxy_vm_zone}/instances/proxy-vm",
      ]
    }
  }
}

# ============================================
# Generate service identity for services (IAM)
# ============================================
# This activates the service agent for a given API
resource "google_project_service_identity" "networking_aiplatform_identity" {
  count   = var.enable_shared_vpc ? 0 : 1
  provider = google-beta
  project = var.networking_project_id
  service = "aiplatform.googleapis.com"
  depends_on = [time_sleep.wait_for_project_apis]
}

resource "google_project_service_identity" "service_aiplatform_identity" {
  for_each = toset(var.vertex_ai_service_project_ids)
  provider = google-beta

  project = each.key
  service = "aiplatform.googleapis.com"

  depends_on = [time_sleep.wait_for_project_apis]
}

resource "google_project_service_identity" "service_compute_identity" {
  for_each = toset(var.vertex_ai_service_project_ids)
  provider = google-beta

  project = each.key
  service = "compute.googleapis.com"

  depends_on = [time_sleep.wait_for_project_apis]
}

# Wait for Service Identity Creation
resource "time_sleep" "wait_for_service_identity_creation" {
  depends_on = [
    google_project_service_identity.networking_aiplatform_identity,
    google_project_service_identity.service_aiplatform_identity,
    google_project_service_identity.service_compute_identity
  ]
  create_duration = "5s"
}

# ============================================
# Step 1: IAM Grants
# ============================================
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
  
  # Service account email mappings for cleaner code
  vertex_ai_service_agents = {
    for project_id in var.vertex_ai_service_project_ids :
    project_id => "service-${data.google_project.vertex_ai_service_projects[project_id].number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
  }
  
  compute_service_accounts = {
    for project_id in var.vertex_ai_service_project_ids :
    project_id => "${data.google_project.vertex_ai_service_projects[project_id].number}-compute@developer.gserviceaccount.com"
  }
  
  networking_vertex_ai_service_agent = "service-${data.google_project.networking_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
}

# ============================================
# Step 1.1: Grant compute.networkUser role to service project Vertex AI service agents on the host project
# ============================================
# Required when network attachments are created in service projects (Service Project Network Attachment Mode)
# Reference: https://cloud.google.com/vertex-ai/docs/general/private-service-connect#shared-vpc
resource "google_project_iam_member" "service_aiplatform_network_user_service_mode" {
  for_each = var.enable_shared_vpc ? toset(var.vertex_ai_service_project_ids) : []
  project = var.networking_project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${local.vertex_ai_service_agents[each.value]}"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.2: Grant compute.networkAdmin role to the appropriate Vertex AI service agent
# ============================================
# In VPC Host Project Network Attachment Mode, grant the role to the networking project's service agent.
resource "google_project_iam_member" "service_aiplatform_network_admin_host_mode" {
  count   = var.enable_shared_vpc ? 0 : 1
  project = var.networking_project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${local.networking_vertex_ai_service_agent}"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# In Service Project Network Attachment Mode, grant the role to each service project's own service agent.
resource "google_project_iam_member" "service_aiplatform_network_admin_service_mode" {
  for_each = var.enable_shared_vpc ? toset(var.vertex_ai_service_project_ids) : []
  project = each.key
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${local.vertex_ai_service_agents[each.key]}"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.3: Grant compute.networkUser role to Vertex AI service agents on each subnet (optional)
# ============================================
# This is required for Service Project Network Attachment to allow service projects to use the network
resource "google_compute_subnetwork_iam_member" "service_aiplatform_network_user" {
  for_each = {
    for item in local.subnet_iam_members :
    item.key => item
  }

  project    = var.networking_project_id
  region     = each.value.region
  subnetwork = google_compute_subnetwork.subnets[each.value.region].name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${local.vertex_ai_service_agents[each.value.project_id]}"

  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.4: Assign DNS Peer role to service projects' Vertex AI service agents in the networking project (host)
# ============================================
resource "google_project_iam_member" "service_dns_peer" {
  for_each = toset(var.vertex_ai_service_project_ids)
  project = var.networking_project_id
  role    = "roles/dns.peer"
  member  = "serviceAccount:${local.vertex_ai_service_agents[each.value]}"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.5: Grant aiplatform.user role to the default compute engine service account
# ============================================
resource "google_project_iam_member" "service_compute_engine_aiplatform_user" {
  for_each = toset(var.vertex_ai_service_project_ids)
  project = each.key
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${local.compute_service_accounts[each.key]}"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.6: Grant Cloud Build Builder role to Compute Engine default service account
# ============================================
resource "google_project_iam_member" "service_compute_engine_cloudbuild_builder" {
  for_each = var.create_vertex_test_container ? toset(var.vertex_ai_service_project_ids) : []
  project = each.value
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${local.compute_service_accounts[each.value]}"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.7: Wait for IAM permissions to propagate before building container
# ============================================
resource "time_sleep" "wait_for_iam_propagation" {
  count = var.create_vertex_test_container ? 1 : 0
  depends_on = [
    google_project_iam_member.service_aiplatform_network_user_service_mode,
    google_project_iam_member.service_aiplatform_network_admin_host_mode,
    google_project_iam_member.service_aiplatform_network_admin_service_mode,
    google_compute_subnetwork_iam_member.service_aiplatform_network_user,
    google_project_iam_member.service_dns_peer,
    google_project_iam_member.service_compute_engine_aiplatform_user,
    google_project_iam_member.service_compute_engine_cloudbuild_builder
  ]
  create_duration = "30s"
}

# ============================================
# 2: Create Artifact Registry repositories in each Vertex AI service project
# ============================================
resource "google_artifact_registry_repository" "vertex_training_repositories" {
  for_each = var.create_vertex_test_container ? toset(var.vertex_ai_service_project_ids) : []

  project       = each.value
  location      = var.artifact_registry_location
  repository_id = var.artifact_registry_repository_id
  description   = var.artifact_registry_description
  format        = var.artifact_registry_format

  depends_on = [time_sleep.wait_for_iam_propagation]
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
      gcloud builds submit ${path.module}/test-container \
        --project=${each.value} \
        --config=${path.module}/test-container/cloudbuild.yaml \
        --substitutions=_ARTIFACT_REGISTRY_LOCATION=${var.artifact_registry_location},_ARTIFACT_REGISTRY_REPO=${var.artifact_registry_repository_id},_IMAGE_NAME=test,_IMAGE_TAG=latest
    EOT
  }

  depends_on = [
    google_artifact_registry_repository.vertex_training_repositories
  ]
}

# ============================================
# Step 3: Create a VPC network in the networking project (VPC host Project)
# ============================================
resource "google_compute_network" "vpc_network" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.networking_project_id
  description             = "VPC network for Private Service Connect Interface to Vertex AI"

  depends_on = [
    time_sleep.wait_for_project_apis
  ]
}

# ============================================
# Step 3.1: Create subnets in each region in the networking project
# ============================================
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

# ============================================
# Step 3.2: Enable Shared VPC on the VPC Host project (optional)
# ============================================
resource "google_compute_shared_vpc_host_project" "host" {
  count   = var.enable_shared_vpc ? 1 : 0
  project = var.networking_project_id
  depends_on = [google_compute_network.vpc_network,]
}

# ============================================
# Step 3.3: Attach service projects to the Shared VPC Host project (optional)
# ============================================
resource "google_compute_shared_vpc_service_project" "service_projects" {
  for_each = var.enable_shared_vpc ? toset(var.vertex_ai_service_project_ids) : []
  host_project    = var.networking_project_id
  service_project = each.value
  depends_on = [google_compute_shared_vpc_host_project.host,]
}

# ============================================
# Step 3.4: Create network attachments in each region in the networking project (VPC Host Project Network Attachment Mode only)
# ============================================
# When enable_shared_vpc = false, network attachments are created in the networking project
resource "google_compute_network_attachment" "psc_attachments" {
  for_each = var.enable_shared_vpc ? toset([]) : toset(var.regions)

  name        = "${each.value}-${var.network_attachment_name_postfix}"
  region      = each.value
  project     = var.networking_project_id
  description = "Network attachment for Private Service Connect Interface to Vertex AI in ${each.value} (VPC Host Project Network Attachment Mode)"

  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.subnets[each.value].self_link]

  # Once Vertex AI Jobs run, some attributes will be managed by Vertex AI
  lifecycle {
    ignore_changes = all
    prevent_destroy = false
  }
}

# ============================================
# Step 3.5: Create network attachments in each region for service projects (Service Project Network Attachment Mode only)
# ============================================
# When enable_shared_vpc = true, network attachments are created in each Vertex AI service project for each region
locals {
  # Create a set of all combinations of service projects and regions
  service_project_regions = flatten([
    for project_id in var.vertex_ai_service_project_ids : [
      for region in var.regions : {
        project_id = project_id
        region     = region
        key        = "${project_id}-${region}"
      }
    ]
  ])
}

resource "google_compute_network_attachment" "psc_attachments_service_projects" {
  for_each = var.enable_shared_vpc ? {
    for item in local.service_project_regions :
    item.key => item
  } : {}

  name        = "${each.value.region}-${var.network_attachment_name_postfix}"
  region      = each.value.region
  project     = each.value.project_id
  description = "Network attachment for Private Service Connect Interface to Vertex AI in ${each.value.region} (Service Project Network Attachment Mode)"

  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.subnets[each.value.region].self_link]

  # Once Vertex AI Jobs run, some attributes will be managed by Vertex AI
  lifecycle {
    ignore_changes = all
    prevent_destroy = false
  }
}

# ============================================
# Step 4: Create a Cloud Router in the first region (optional)
# ============================================
resource "google_compute_router" "router" {
  count   = var.create_proxy_vm ? 1 : 0
  name    = "cloud-router-for-nat"
  network = google_compute_network.vpc_network.name
  project = var.networking_project_id
  region  = var.regions[0]
}

# ============================================
# Step 4: Create a Cloud NAT gateway in the first region (optional)
# ============================================
resource "google_compute_router_nat" "nat" {
  count                              = var.create_proxy_vm ? 1 : 0
  name                               = "cloud-nat-${var.regions[0]}"
  router                             = google_compute_router.router[0].name
  project                            = var.networking_project_id
  region                             = var.regions[0]
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ALL"
  }
}

# ============================================
# Step 5: Create firewall rule that allows SSH access on TCP port 22 in the networking project
# ============================================
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

# ============================================
# Step 5.1: Create firewall rule that allows HTTPS traffic on TCP port 443 in the networking project
# ============================================
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

# ============================================
# Step 5.2: Create firewall rule that allows ICMP traffic (ping requests) in the networking project
# ============================================
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

# ============================================
# Step 5.3: Create firewall rule that allows all ICMP, TCP, and UDP traffic (optional)
# ============================================
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


# ============================================
# Step 6: Create a proxy VM in the first region (optional)
# ============================================
resource "google_compute_instance" "proxy_vm" {
  count        = var.create_proxy_vm ? 1 : 0
  project      = var.networking_project_id
  zone         = var.proxy_vm_zone
  name         = "proxy-vm"
  machine_type = var.proxy_vm_machine_type
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnets[var.regions[0]].id
  }
  # To enable this need to change the org policy: constraints/compute.vmCanIpForward
  can_ip_forward = true
  metadata = {
    startup-script = <<-EOT
      #! /bin/bash
      # Wait for network config
      sleep 10

      # Install Tinyproxy
      apt-get update -y
      apt-get install -y tinyproxy

      # Configure Tinyproxy
      cat << EOF > /etc/tinyproxy/tinyproxy.conf
      # Default user/group for tinyproxy package on Debian
      User tinyproxy
      Group tinyproxy

      # Port to listen on
      Port 3128

      # Address to listen on (0.0.0.0 for all interfaces)
      Listen 0.0.0.0
      # Timeout for connections
      Timeout 600

      # Log file location
      LogFile "/var/log/tinyproxy/tinyproxy.log"
      # Process ID file location
      PidFile "/, some attributes will be managed by Vertex AI/tinyproxy/tinyproxy.pid"

      # Max number of clients
      MaxClients 100

      # Allow RFC1918 networks
      Allow 10.0.0.0/8
      Allow 172.16.0.0/12
      Allow 192.168.0.0/16

      # Deny networks

      # Required for HTTP 1.1
      ViaProxyName "tinyproxy"
      EOF

      # Ensure log directory exists and has correct permissions
      mkdir -p /var/log/tinyproxy
      chown tinyproxy:tinyproxy /var/log/tinyproxy
      # Restart Tinyproxy
      systemctl restart tinyproxy
      systemctl enable tinyproxy
    EOT
  }
  depends_on = [google_project_organization_policy.ip_forward]
}

# ============================================
# Step 7: Create a private Cloud DNS zone (optional)
# ============================================
resource "google_dns_managed_zone" "private_zone" {
  count       = var.create_dns_zone ? 1 : 0
  project     = var.networking_project_id
  name        = var.dns_zone_name
  dns_name    = var.dns_domain
  description = "Private DNS zone for demo purposes"
  visibility  = "private"
  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc_network.id
    }
  }
}

# ============================================
# Step 7.1: Create a DNS A record for the proxy VM (optional)
# ============================================
resource "google_dns_record_set" "proxy_vm_record" {
  count        = var.create_dns_zone && var.create_proxy_vm ? 1 : 0
  project      = var.networking_project_id
  managed_zone = google_dns_managed_zone.private_zone[0].name
  name         = "proxy-vm.${var.dns_domain}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.proxy_vm[0].network_interface[0].network_ip]
}

# ============================================
# Step 8: Create a Vertex AI Custom Job in each service project using the REST API
# ============================================
# Note: Upon the initial , some attributes will be managed by Vertex AI, the Vertex AI Training Custom Job may take up to 15 minutes to start.
# Its status can be monitored by navigating to the following in the Google Cloud Console:
# Vertex AI → Training → Custom jobs
# https://console.cloud.google.com/vertex-ai/training/custom-jobs
resource "null_resource" "submit_training_job" {
  for_each = var.create_training_job ? {
    for item in local.service_project_regions :
    item.key => item
  } : {}

  triggers = {
    # This ensures the job is re-created if the image or network attachment changes
    image_uri          = google_artifact_registry_repository.vertex_training_repositories[each.value.project_id].location == null ? "" : "${google_artifact_registry_repository.vertex_training_repositories[each.value.project_id].location}-docker.pkg.dev/${each.value.project_id}/${google_artifact_registry_repository.vertex_training_repositories[each.value.project_id].repository_id}/test:latest"
    network_attachment = "${var.enable_shared_vpc ? "projects/${each.value.project_id}/regions/${each.value.region}/networkAttachments/${each.value.region}-${var.network_attachment_name_postfix}" : "projects/${var.networking_project_id}/regions/${each.value.region}/networkAttachments/${each.value.region}-${var.network_attachment_name_postfix}"}"
    # Force submitting a new job on every apply:
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF > request-${each.key}.json
      {
        "display_name": "CPU Test Job PSC-I",
        "job_spec": {
          "worker_pool_specs": [
            {
              "machine_spec": {
                "machine_type": "n2-standard-4"
              },
              "replica_count": 1,
              "container_spec": {
                "image_uri": "${self.triggers.image_uri}",
                "args": [
                  "--sleep=600s"
                ]
              },
              "disk_spec": {
                "boot_disk_type": "pd-ssd",
                "boot_disk_size_gb": 100
              }
            }
          ],
          "service_account": "${local.compute_service_accounts[each.value.project_id]}",
          "psc_interface_config": {
            "network_attachment": "${self.triggers.network_attachment}"
            ${var.create_dns_zone ? ",\"dns_peering_configs\": [{\"domain\": \"${var.dns_domain}\",\"target_project\": \"${var.networking_project_id}\",\"target_network\": \"${google_compute_network.vpc_network.name}\"}]" : ""}
          },
          "enable_web_access": true
        },
        "labels": {
          "network_type": "psc-i"
        }
      }
      EOF

      curl -X POST \
           -H "Authorization: Bearer $(gcloud auth print-access-token)" \
           -H "Content-Type: application/json; charset=utf-8" \
           -d @request-${each.key}.json \
           "https://${each.value.region}-aiplatform.googleapis.com/v1/projects/${each.value.project_id}/locations/${each.value.region}/customJobs"
    EOT
  }

  depends_on = [null_resource.build_vertex_training_container]
}
