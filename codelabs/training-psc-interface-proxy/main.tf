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
  region  = var.region  # Use first region as default
}

# ============================================
# Data source to get networking project number
# ============================================
data "google_project" "networking_project" {
  project_id = var.networking_project_id
}

# Data source to get project numbers for all Vertex AI service projects
data "google_project" "vertex_ai_service_project" {
  project_id = var.vertex_ai_service_project_id
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

# In the Vertex AI service project
resource "google_project_service" "service_project_apis" {
  for_each = toset(local.service_apis)
  project = var.vertex_ai_service_project_id
  service = each.value
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
# Create Storage Bucket in the Vertex AI service project
# ============================================
resource "google_storage_bucket" "vertex_ai_bucket" {
  name                        = "${var.vertex_ai_service_project_id}-aiplatform"
  project                     = var.vertex_ai_service_project_id
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
  depends_on = [time_sleep.wait_for_project_apis]
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
        "projects/${var.networking_project_id}/zones/${var.vm_zone}/instances/proxy-vm",
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
  provider = google-beta
  project = var.vertex_ai_service_project_id
  service = "aiplatform.googleapis.com"
  depends_on = [time_sleep.wait_for_project_apis]
}

resource "google_project_service_identity" "service_compute_identity" {
  provider = google-beta
  project = var.vertex_ai_service_project_id
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
# Step 1: Grant compute.networkUser role to service project Vertex AI service agents on the host project
# ============================================
# Required when network attachments are created in service projects (Service Project Network Attachment Mode)
# Reference: https://cloud.google.com/vertex-ai/docs/general/private-service-connect#shared-vpc
resource "google_project_iam_member" "service_aiplatform_network_user_service_mode" {
  count   = var.enable_shared_vpc ? 1 : 0
  project = var.networking_project_id
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:service-${data.google_project.vertex_ai_service_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.1: Grant compute.networkAdmin role to the appropriate Vertex AI service agent
# ============================================
# In VPC Host Project Network Attachment Mode, grant the role to the networking project's service agent.
resource "google_project_iam_member" "service_aiplatform_network_admin_host_mode" {
  count   = var.enable_shared_vpc ? 0 : 1
  project = var.networking_project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:service-${data.google_project.networking_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# In Service Project Network Attachment Mode, grant the role to the service project's own service agent.
resource "google_project_iam_member" "service_aiplatform_network_admin_service_mode" {
  count   = var.enable_shared_vpc ? 1 : 0
  project = var.vertex_ai_service_project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:service-${data.google_project.vertex_ai_service_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.2: Grant compute.networkUser role to Vertex AI service agents on each subnet (optional)
# ============================================
# This is required for Service Project Network Attachment to allow service projects to use the network
resource "google_compute_subnetwork_iam_member" "service_aiplatform_network_user" {
  count      = var.enable_shared_vpc ? 1 : 0
  project    = var.networking_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.intf_subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.vertex_ai_service_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.3: Assign DNS Peer role to service projects' Vertex AI service agents in the networking project (host)
# ============================================
resource "google_project_iam_member" "service_dns_peer" {
  project = var.networking_project_id
  role    = "roles/dns.peer"
  member  = "serviceAccount:service-${data.google_project.vertex_ai_service_project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.4: Grant aiplatform.user role to the default compute engine service account
# ============================================
resource "google_project_iam_member" "service_compute_engine_aiplatform_user" {
  project = var.vertex_ai_service_project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${data.google_project.vertex_ai_service_project.number}-compute@developer.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.5: Grant storage.admin role to the default compute engine service account
# ============================================
resource "google_project_iam_member" "service_compute_engine_storage_admin" {
  project = var.vertex_ai_service_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${data.google_project.vertex_ai_service_project.number}-compute@developer.gserviceaccount.com"
  depends_on = [time_sleep.wait_for_service_identity_creation]
}

# ============================================
# Step 1.6: Grant Cloud Build Builder role to Compute Engine default service account
# ============================================
resource "google_project_iam_member" "service_compute_engine_cloudbuild_builder" {
  count   = var.create_vertex_test_container ? 1 : 0
  project = var.vertex_ai_service_project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${data.google_project.vertex_ai_service_project.number}-compute@developer.gserviceaccount.com"
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
    google_project_iam_member.service_compute_engine_storage_admin,
    google_project_iam_member.service_compute_engine_cloudbuild_builder
  ]
  create_duration = "30s"
}

# ============================================
# Step 2: Create Artifact Registry repositories in each Vertex AI service project
# ============================================
resource "google_artifact_registry_repository" "vertex_training_repositories" {
  count         = var.create_vertex_test_container ? 1 : 0
  project       = var.vertex_ai_service_project_id
  location      = var.artifact_registry_location
  repository_id = var.artifact_registry_repository_id
  description   = var.artifact_registry_description
  format        = var.artifact_registry_format

  depends_on = [time_sleep.wait_for_iam_propagation]
}

# Automatically build and push the container when Terraform is applied
resource "null_resource" "build_vertex_training_container" {
  count = var.create_vertex_test_container ? 1 : 0

  # Trigger rebuild when configuration changes
  triggers = {
    artifact_registry_location = var.artifact_registry_location
    artifact_registry_repo     = var.artifact_registry_repository_id
    # Uncomment to force rebuild on every apply:
    # timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud builds submit ${path.module}/test-proxy-container \
        --project=${var.vertex_ai_service_project_id} \
        --config=${path.module}/test-proxy-container/cloudbuild.yaml \
        --substitutions=_ARTIFACT_REGISTRY_LOCATION=${var.artifact_registry_location},_ARTIFACT_REGISTRY_REPO=${var.artifact_registry_repository_id},_IMAGE_NAME=${var.image_name},_IMAGE_TAG=latest
    EOT
  }

  depends_on = [google_artifact_registry_repository.vertex_training_repositories]
}

# ============================================
# Step 3: Create a VPC network in the networking project (VPC host Project)
# ============================================
resource "google_compute_network" "vpc_network" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.networking_project_id
  description             = "VPC network for Private Service Connect Interface to Vertex AI"
  depends_on = [time_sleep.wait_for_project_apis]
}

# ============================================
# Step 3.1: Create subnets in the networking project
# ============================================
resource "google_compute_subnetwork" "class_e_subnet" {
  name          = "class-e-subnet"
  ip_cidr_range = "240.0.0.0/4"
  region        = var.region
  network       = google_compute_network.vpc_network.id
  project       = var.networking_project_id
}

resource "google_compute_subnetwork" "rfc1918_subnet" {
  name          = "rfc1918-subnet"
  ip_cidr_range = "10.10.10.0/28"
  region        = var.region
  network       = google_compute_network.vpc_network.id
  project       = var.networking_project_id
}

resource "google_compute_subnetwork" "intf_subnet" {
  name          = "intf-subnet1"
  ip_cidr_range = "192.168.10.0/28"
  region        = var.region
  network       = google_compute_network.vpc_network.id
  project       = var.networking_project_id
  description   = "Subnet for Private Service Connect Interface Network Attachment"
}

# ============================================
# Step 3.2: Enable Shared VPC on the VPC Host project (optional)
# ============================================
resource "google_compute_shared_vpc_host_project" "host_project" {
  count   = var.enable_shared_vpc ? 1 : 0
  project = var.networking_project_id
  depends_on = [google_compute_network.vpc_network]
}

# ============================================
# Step 3.3: Attach service projects to the Shared VPC Host project (optional)
# ============================================
resource "google_compute_shared_vpc_service_project" "service_project" {
  count   = var.enable_shared_vpc ? 1 : 0
  host_project    = var.networking_project_id
  service_project = var.vertex_ai_service_project_id
  depends_on = [google_compute_shared_vpc_host_project.host_project]
}

# ============================================
# Step 3.4: Create network attachments in each region in the networking project (VPC Host Project Network Attachment Mode only)
# ============================================
# When enable_shared_vpc = false, network attachments are created in the networking project
resource "google_compute_network_attachment" "psc_attachment_networking_project" {
  count       = var.enable_shared_vpc ? 0 : 1
  name        = "${var.region}-${var.network_attachment_name_postfix}"
  region      = var.region
  project     = var.networking_project_id
  description = "Network attachment for Private Service Connect Interface to Vertex AI in ${var.region} (VPC Host Project Network Attachment Mode)"

  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.intf_subnet.self_link]

  # Once Vertex AI Jobs run, some attributes will be managed by Vertex AI
  lifecycle {
    ignore_changes = all
    prevent_destroy = true
  }
}

# ============================================
# Step 3.5: Create network attachments in each region for service projects (Service Project Network Attachment Mode only)
# ============================================
# When enable_shared_vpc = true, network attachments are created in each Vertex AI service project for each region
resource "google_compute_network_attachment" "psc_attachment_service_project" {
  count       = var.enable_shared_vpc ? 1 : 0
  name        = "${var.region}-${var.network_attachment_name_postfix}"
  region      = var.region
  project     = var.vertex_ai_service_project_id
  description = "Network attachment for Private Service Connect Interface to Vertex AI in ${var.region} (Service Project Network Attachment Mode)"

  connection_preference = "ACCEPT_AUTOMATIC"
  subnetworks           = [google_compute_subnetwork.intf_subnet.self_link]

  # Once Vertex AI Jobs run, some attributes will be managed by Vertex AI
  lifecycle {
    ignore_changes = all
    prevent_destroy = true
  }

  depends_on = [google_compute_shared_vpc_service_project.service_project]
}

# ============================================
# Step 4: Create a Cloud Router in the first region (optional)
# ============================================
resource "google_compute_router" "router" {
  count   = var.create_nat_gateway ? 1 : 0
  name    = "cloud-router-for-nat"
  network = google_compute_network.vpc_network.name
  project = var.networking_project_id
  region  = var.region
}

# ============================================
# Step 4.1: Create a Cloud NAT gateway in the first region (optional)
# ============================================
resource "google_compute_router_nat" "nat" {
  count                              = var.create_nat_gateway ? 1 : 0
  name                               = "cloud-nat-${var.region}"
  router                             = google_compute_router.router[0].name
  project                            = var.networking_project_id
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ALL"
  }
}

# ============================================
# Step 5: Create firewall rule that allows SSH access from IAP
# ============================================
resource "google_compute_firewall" "allow_ssh_iap" {
  name    = "ssh-iap-consumer"
  network = google_compute_network.vpc_network.name
  project = var.networking_project_id
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  description   = "Allow SSH access from IAP"
}

# ============================================
# Step 5.1: Create firewall rule that allows access from the PSC Network Attachment subnet to the proxy-vm
# ============================================
resource "google_compute_firewall" "allow_access_to_proxy" {
  name    = "allow-access-to-proxy"
  network = google_compute_network.vpc_network.name
  project = var.networking_project_id
  allow {
    protocol = "all"
  }
  source_ranges      = [google_compute_subnetwork.intf_subnet.ip_cidr_range]
  destination_ranges = [google_compute_subnetwork.rfc1918_subnet.ip_cidr_range]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# ============================================
# Step 5.2: Create firewall rule that allows access from the proxy-vm subnet to the class-e subnet
# ============================================
resource "google_compute_firewall" "allow_access_to_class_e" {
  name    = "allow-access-to-class-e"
  network = google_compute_network.vpc_network.name
  project = var.networking_project_id
  allow {
    protocol = "all"
  }
  source_ranges      = [google_compute_subnetwork.rfc1918_subnet.ip_cidr_range]
  destination_ranges = [google_compute_subnetwork.class_e_subnet.ip_cidr_range]
  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
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
# Step 6: Create a proxy VM (optional)
# ============================================
resource "google_compute_instance" "proxy_vm" {
  count        = var.create_proxy_vm ? 1 : 0
  project      = var.networking_project_id
  zone         = var.vm_zone
  name         = "proxy-vm"
  machine_type = var.vm_machine_type
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.rfc1918_subnet.id
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
  allow_stopping_for_update = true
  # To enable this need to change the org policy: constraints/compute.vmCanIpForward
  can_ip_forward = true
  metadata = {
    startup-script = <<-EOT
      #! /bin/bash
      # Wait for network config
      sleep 10

      # Install Tinyproxy
      sudo apt-get update -y
      sudo apt-get install tcpdump
      sudo apt-get install tinyproxy -y
      sudo apt-get install apache2 -y

      # sudo systemctl restart apache2
      sudo service apache2 restart
      echo 'proxy server !!' | tee /var/www/html/index.html

      # Configure Tinyproxy
      cat << EOF > /etc/tinyproxy/tinyproxy.conf

      # Port to listen on
      Port 8888

      # Address to listen on (0.0.0.0 for all interfaces)
      Listen 0.0.0.0

      # Locate the "Allow" configuration line to allow requests ONLY from the PSC Network Attachment Subnet
      Allow 192.168.10.0/24
      EOF

      # Restart Tinyproxy
      sudo systemctl restart tinyproxy
      # Validate the tinyproxy service is running:
      sudo systemctl status tinyproxy
    EOT
  }
  depends_on = [google_project_organization_policy.ip_forward]
}

# ============================================
# Step 6.1: Create a class-e VM (optional)
# ============================================
resource "google_compute_instance" "class_e_vm" {
  count        = var.create_class_e_vm ? 1 : 0
  project      = var.networking_project_id
  zone         = var.vm_zone
  name         = "class-e-vm"
  machine_type = var.vm_machine_type
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }
  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.class_e_subnet.id
  }
  shielded_instance_config {
    enable_secure_boot = true
  }
  metadata = {
    startup-script = <<-EOT
      #! /bin/bash
      sudo apt-get update
      sudo apt-get install tcpdump
      sudo apt-get install apache2 -y
      sudo service apache2 restart
      echo 'Class-e server !!' | tee /var/www/html/index.html
    EOT
  }
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
# Step 7.2: Create a DNS A record for the class-e VM (optional)
# ============================================
resource "google_dns_record_set" "class_e_vm_record" {
  count        = var.create_dns_zone && var.create_class_e_vm ? 1 : 0
  project      = var.networking_project_id
  managed_zone = google_dns_managed_zone.private_zone[0].name
  name         = "class-e-vm.${var.dns_domain}"
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.class_e_vm[0].network_interface[0].network_ip]
}

# ============================================
# Step 8: Create a Vertex AI Custom Job in the service project using the REST API
# ============================================
# Note: Upon the initial run, the Vertex AI Training Custom Job may take up to 15 minutes to start.
# Its status can be monitored by navigating to the following in the Google Cloud Console:
# Vertex AI → Training → Custom jobs
# https://console.cloud.google.com/vertex-ai/training/custom-jobs
resource "null_resource" "submit_training_job_psci_nonrfc" {
  count = var.create_training_job ? 1 : 0
  triggers = {
    # This ensures the job is re-created if the image or network attachment changes
    image_uri          = "${google_artifact_registry_repository.vertex_training_repositories[0].location}-docker.pkg.dev/${var.vertex_ai_service_project_id}/${google_artifact_registry_repository.vertex_training_repositories[0].repository_id}/${var.image_name}:latest"
    network_attachment = var.enable_shared_vpc ? "${google_compute_network_attachment.psc_attachment_service_project[0].id}" : "${google_compute_network_attachment.psc_attachment_networking_project[0].id}"
    # Force submitting a new job on every apply:
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF > request-psci-nonrfc-test.json
      {
        "display_name": "Test-PSC-I-nonRFC-${formatdate("YYYY-MM-DD-hh:mm:ss", timestamp())}",
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
                ],
                "env": [
                  {
                    "name": "NONRFC_URL",
                    "value": "http://class-e-vm.${trimsuffix(var.dns_domain, ".")}"
                  },
                  {
                    "name": "PROXY_VM_IP",
                    "value": "proxy-vm.${trimsuffix(var.dns_domain, ".")}"
                  },
                  {
                    "name": "PROXY_VM_PORT",
                    "value": "8888"
                  }
                ]
              },
              "disk_spec": {
                "boot_disk_type": "pd-ssd",
                "boot_disk_size_gb": 100
              }
            }
          ],
          "service_account": "${data.google_project.vertex_ai_service_project.number}-compute@developer.gserviceaccount.com",
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
           -d @request-psci-nonrfc-test.json \
           "https://${var.region}-aiplatform.googleapis.com/v1/projects/${var.vertex_ai_service_project_id}/locations/${var.region}/customJobs"
    EOT
  }

  depends_on = [null_resource.build_vertex_training_container]
}

# ============================================
# Step 9: Create a Vertex AI Pipeline Job the service project using the REST API
# ============================================
# Note: Upon the initial run, the Vertex AI Training Custom Job may take up to 15 minutes to start.
# Its status can be monitored by navigating to the following in the Google Cloud Console:
# Vertex AI → Training → Custom jobs
# https://console.cloud.google.com/vertex-ai/training/custom-jobs

# REST API
# https://cloud.google.com/vertex-ai/docs/reference/rest/v1/projects.locations.pipelineJobs#PipelineJob

# PSC-I in Pipelines
# https://docs.cloud.google.com/vertex-ai/docs/pipelines/configure-private-service-connect

locals {
  rendered_pipeline_spec = templatefile("${path.module}/pipeline-compiled/dns_peering_test_pipeline.tftpl", {
      default_pipeline_root = "${google_storage_bucket.vertex_ai_bucket.url}/pipeline_root/intro"
      image_uri             = "${var.artifact_registry_location}-docker.pkg.dev/${var.vertex_ai_service_project_id}/${var.artifact_registry_repository_id}/${var.image_name}:latest"
    }
  )
  pipeline_yaml_output = yamldecode(local.rendered_pipeline_spec)
  pipeline_json_output = jsonencode(local.pipeline_yaml_output)
}

resource "null_resource" "submit_pipeline_dns_peering" {
  count = var.create_training_job ? 1 : 0
  triggers = {
    # This ensures the job is re-created if the image or network attachment changes
    image_uri          = "${google_artifact_registry_repository.vertex_training_repositories[0].location}-docker.pkg.dev/${var.vertex_ai_service_project_id}/${google_artifact_registry_repository.vertex_training_repositories[0].repository_id}/${var.image_name}:latest"
    network_attachment = var.enable_shared_vpc ? "${google_compute_network_attachment.psc_attachment_service_project[0].id}" : "${google_compute_network_attachment.psc_attachment_networking_project[0].id}"
    # Force submitting a new job on every apply:
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      cat <<EOF > request-pipeline-test.json
      {
        "display_name": "dns-peering-test-pipeline",
        "pipeline_spec": ${local.pipeline_json_output},
        "runtime_config": {
          "gcs_output_directory": "${google_storage_bucket.vertex_ai_bucket.url}",
          "parameterValues": {
            "dns_domain": "class-e-vm.${trimsuffix(var.dns_domain, ".")}",
            "proxy_vm_ip": "proxy-vm.${trimsuffix(var.dns_domain, ".")}",
            "proxy_vm_port": "8888"
          }
        },
        "service_account": "${data.google_project.vertex_ai_service_project.number}-compute@developer.gserviceaccount.com",
        "psc_interface_config": {
          "network_attachment": "${self.triggers.network_attachment}"
          ${var.create_dns_zone ? ",\"dns_peering_configs\": [{\"domain\": \"${var.dns_domain}\",\"target_project\": \"${var.networking_project_id}\",\"target_network\": \"${google_compute_network.vpc_network.name}\"}]" : ""}
        },
        "labels": {
          "network_type": "psc-i"
        }
      }
      EOF

      curl -X POST \
           -H "Authorization: Bearer $(gcloud auth print-access-token)" \
           -H "Content-Type: application/json; charset=utf-8" \
           -d @request-pipeline-test.json \
           "https://${var.region}-aiplatform.googleapis.com/v1/projects/${var.vertex_ai_service_project_id}/locations/${var.region}/pipelineJobs?pipelineJobId=dns-peering-test-pipeline-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}"
    EOT
  }

  depends_on = [null_resource.build_vertex_training_container]
}
