# Vertex AI Private Service Connect Interface - Terraform

This Terraform configuration automates the setup of a Private Service Connect (PSC) Interface for Vertex AI, supporting both standalone and Shared VPC architectures.

This terraform creates the resources created by this codelab: [Vertex AI Pipelines PSC Interface Explicit Proxy](https://codelabs.developers.google.com/pipelines-psc-interface-proxy)

## Overview

This module creates the necessary resources for a PSC-enabled network, including:

-   A VPC network and subnet.
-   Network Attachments for PSC.
-   Shared VPC configuration (optional).
-   IAM bindings for Vertex AI service agents.
-   Firewall rules.

## What you'll build
In this tutorial, you're going to build a comprehensive Vertex AI Training deployment with Private Service Connect (PSC) Interface to allow connectivity from the producer to the consumer's compute as illustrated in the figures (see **VPC Host Network** or **Service Project Network Attachment** Mode below) below targeting rfc-1928 endpoints.

You'll create a single psc-network-attachment in the consumer VPC leveraging DNS peering to resolve the consumers VMs in the tenant project hosting Vertex AI Training resulting in the following use cases:

1. Deploy Vertex AI Training and configuring a proxy VM to act as an explicit proxy, allowing Vertex AI training to access the proxy VM's DNS endpoint.

## What you'll learn
1. How to create a network attachment
2. How a producer can use a network attachment to create a PSC interface
3. How to establish communication from the producer to the consumer using DNS Peering

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
| `enable_allow_all_firewall` | Enable all traffic rule | `false` |
| `all_traffic_source_ranges` | Source ranges for all traffic | `["10.0.0.0/8"]` |
| `create_nat_gateway` | If true, creates a Cloud Router and a Cloud NAT gateway in the region. | `true` |
| `create_class_e_vm` | If true, creates a class-e VM in the region. | `true` |
| `vm_zone` | The zone for the VMs. Should be in the region. | `us-central1-a` |
| `vm_machine_type` | The machine type for the VMs. | `e2-micro` |
| `create_dns_zone` | If true, creates a private Cloud DNS zone and an A record for the proxy VM. | `false` |
| `dns_zone_name` | The name of the Cloud DNS managed zone. | `private-dns-demo` |
| `dns_domain` | The DNS name of the managed zone (e.g., 'demo.com.'). | `demo.com.` |
| `create_vertex_test_container` | Enable creation of Artifact Registry repository and Cloud Build API for Vertex AI training containers | `false` |
| `artifact_registry_repository_id` | The ID of the Artifact Registry repository to create | `pipelines-test-repo-psc` |
| `image_name` | The name of the container image. | `nonrfc-ip-call` |
| `create_training_job` | If true, creates a Vertex AI custom training job in each service project using the created resources. | `false` |

## Usage with Vertex AI

This configuration supports two modes depending on the `enable_shared_vpc` variable.

### 1. VPC Host Network Attachment Mode (`enable_shared_vpc = false`)

-   A single network attachment is created in the networking project.
-   Use this network attachment for Vertex AI resources in any service project.

### 2. Service Project Network Attachment Mode (`enable_shared_vpc = true`)

-   A full Shared VPC architecture is created.
-   Each service project gets its own network attachment.
-   When creating Vertex AI resources, use the network attachment from the *same* service project.

## Files

-   **main.tf**: Main Terraform configuration.
-   **variables.tf**: Variable definitions.
-   **outputs.tf**: Output values.
-   **terraform-example.tfvars**: Your variable values.

## Cleanup

```bash
terraform destroy
```

## Additional Resources

-   [Set up a Private Service Connect interface for Vertex AI resources](https://cloud.google.com/vertex-ai/docs/general/vpc-psc-i-setup)
-   [Use Private Service Connect interface for Vertex AI Training](https://docs.cloud.google.com/vertex-ai/docs/training/psc-i-egress)
-   [Codelab: Vertex AI Pipelines PSC Interface Explicit Proxy](https://codelabs.developers.google.com/pipelines-psc-interface-proxy)
-   [Shared VPC Documentation](https://cloud.google.com/vpc/docs/shared-vpc)
-   [Network Attachments Documentation](https://cloud.google.com/vpc/docs/about-network-attachments)

## License

Copyright 2025 Google LLC. Licensed under the Apache License, Version 2.0.
