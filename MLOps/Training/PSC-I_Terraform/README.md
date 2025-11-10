# Vertex AI Private Service Connect Interface - Terraform

This Terraform configuration automates the setup of a Private Service Connect (PSC) Interface for Vertex AI, supporting both standalone and Shared VPC architectures.

## Overview

This module creates the necessary resources for a PSC-enabled network, including:

-   A VPC network and subnet.
-   Network Attachments for PSC.
-   Shared VPC configuration (optional).
-   IAM bindings for Vertex AI service agents.
-   Firewall rules.

## Architectures

### VPC Host Network Attachment Mode
![vpc_host_network_attachment](resources/images/vpc-host-project-network-attachment.png)

### Service Project Network Attachment Mode
![service_project_network_attachment](resources/images/service-project-network-attachment.png)

## Prerequisites

1.  **Google Cloud Projects**: A networking project and one or more Vertex AI service projects.
2.  **Terraform** >= 1.0
3.  **gcloud CLI**
4.  **IAM Permissions**:
    -   **Networking Project**: `roles/compute.networkAdmin`, `roles/compute.xpnAdmin`, `roles/iam.securityAdmin`, `roles/dns.admin`
    -   **Service Project(s)**: `roles/compute.networkUser`, `roles/resourcemanager.projectIamAdmin`

## Quick Start

1.  **Configure `terraform.tfvars`**:
    ```hcl
    networking_project_id = "your-networking-project-id"
    vertex_ai_service_project_ids = ["your-vertex-ai-project-1"]
    region                  = "us-central1"
    ```
2.  **Initialize and Apply**:
    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

## Configuration

| Variable | Description | Default |
|---|---|---|
| `networking_project_id` | Networking project ID (VPC Host project) | **Required** |
| `vertex_ai_service_project_ids` | List of Vertex AI service project IDs | **Required** |
| `region` | Region for resources | **Required** |
| `network_name` | Name of the VPC network | `vertex-ai-psc-network` |
| `subnet_name` | Name of the subnet | `vertex-ai-psc-subnet` |
| `subnet_primary_range` | Primary IP CIDR range | `10.0.0.0/24` |
| `enable_shared_vpc` | Enable Shared VPC configuration | `false` |
| `ssh_source_ranges` | Source IP ranges for SSH | `["0.0.0.0/0"]` |
| `https_source_ranges` | Source IP ranges for HTTPS | `["0.0.0.0/0"]` |
| `icmp_source_ranges` | Source IP ranges for ICMP | `["0.0.0.0/0"]` |
| `enable_allow_all_firewall` | Enable all traffic rule | `false` |
| `all_traffic_source_ranges` | Source ranges for all traffic | `["10.0.0.0/8"]` |
| `create_vertex_test_container` | Enable creation of Artifact Registry repository and Cloud Build API for Vertex AI training containers | `false` |
| `create_training_job` | If true, creates a Vertex AI custom training job in each service project using the created resources. | `false` |
| `create_proxy_vm` | If true, creates a proxy VM in the first region. | `false` |
| `proxy_vm_zone` | The zone for the proxy VM. Should be in the first region of the `regions` list. | `us-central1-a` |
| `proxy_vm_machine_type` | The machine type for the proxy VM. | `e2-micro` |
| `create_dns_zone` | If true, creates a private Cloud DNS zone and an A record for the proxy VM. | `false` |
| `dns_zone_name` | The name of the Cloud DNS managed zone. | `private-dns-demo` |
| `dns_domain` | The DNS name of the managed zone (e.g., 'demo.com.'). | `demo.com.` |

## Usage with Vertex AI

This configuration supports two modes depending on the `enable_shared_vpc` variable.

### 1. VPC Host Network Attachment Mode (`enable_shared_vpc = false`)

-   A single network attachment is created in the networking project.
-   Use this network attachment for Vertex AI resources in any service project.

```bash
NETWORK_ATTACHMENT=$(terraform output -raw network_attachment_self_link)

gcloud ai custom-jobs create \
  --project=YOUR_SERVICE_PROJECT_ID \
  --region=us-central1 \
  --display-name=my-psc-training-job \
  --network=${NETWORK_ATTACHMENT} \
  --worker-pool-spec=machine-type=n1-standard-4,replica-count=1,container-image-uri=gcr.io/your-image
```

### 2. Service Project Network Attachment Mode (`enable_shared_vpc = true`)

-   A full Shared VPC architecture is created.
-   Each service project gets its own network attachment.
-   When creating Vertex AI resources, use the network attachment from the *same* service project.

```bash
# Get the network attachment for a specific service project
NETWORK_ATTACHMENT="projects/service-project-1/regions/us-central1/networkAttachments/vertex-ai-psc-attachment"

gcloud ai custom-jobs create \
  --project=service-project-1 \
  --region=us-central1 \
  --display-name=my-psc-training-job \
  --network=${NETWORK_ATTACHMENT} \
  --worker-pool-spec=machine-type=n1-standard-4,replica-count=1,container-image-uri=gcr.io/your-image
```

## Files

-   **main.tf**: Main Terraform configuration.
-   **variables.tf**: Variable definitions.
-   **outputs.tf**: Output values.
-   **terraform.tfvars**: Your variable values.

## Cleanup

```bash
terraform destroy
```

## Additional Resources

-   [Vertex AI Private Service Connect Documentation](https://cloud.google.com/vertex-ai/docs/general/private-service-connect)
-   [Shared VPC Documentation](https://cloud.google.com/vpc/docs/shared-vpc)
-   [Network Attachments Documentation](https://cloud.google.com/vpc/docs/about-network-attachments)

## License

Copyright 2025 Google LLC. Licensed under the Apache License, Version 2.0.
