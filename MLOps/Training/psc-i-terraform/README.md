# Vertex AI Private Service Connect Interface - Terraform

This Terraform configuration automates the setup of a Private Service Connect (PSC) Interface for Vertex AI, supporting both standalone and Shared VPC architectures.

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

> [!WARNING]
> **Note:** Tutorial offers configuration and validation steps based on the illustrated topology, modify the procedure as needed to meet your organization's requirements.

## Architectures

### VPC Host Network Attachment Mode
-   A single network attachment is created in the networking project.
-   Use this network attachment for Vertex AI resources in any service project.

![vpc_host_network_attachment](resources/images/vpc-host-project-network-attachment.png)

### Service Project Network Attachment Mode
-   A full Shared VPC architecture is created.
-   Each service project gets its own network attachment.
-   When creating Vertex AI resources, use the network attachment from the *same* service project.

![service_project_network_attachment](resources/images/service-project-network-attachment.png)

### **Vertex AI PSC-Interface VPC-SC considerations**

* When your project is part of a VPC Service Controls perimeter, the Google-managed tenants default internet access is blocked by the perimeter to prevent data exfiltration.
* To allow the deployment  access to the public internet in this scenario, you must explicitly configure a secure egress path that routes traffic through your VPC. The recommended way to achieve this is by setting up a proxy server inside your VPC perimeter with a RFC1918 address and create a Cloud NAT gateway to allow the proxy VM to access the internet.

> [!NOTE]
> **Note:** Vertex AI Training deployments require an explicit proxy for Internet Egress when VPC-SC is used. If VPC-SC is not enabled, internet egress is provided through the Google managed tenant vpc.

For additional information, refer to the following resources:

[Set up a Private Service Connect interface for Vertex AI resources | Google Cloud](https://cloud.google.com/vertex-ai/docs/general/vpc-psc-i-setup#set-up-vpc-network)

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

## Submit Vertex AI Training Jobs
The Vertex AI Training job is configured to be run on a `terraform apply`. Running `terraform apply` will kick off new Vertex AI Training jobs. You can navitate to the custom job in Vertex AI Training to use the [interactive shell](https://docs.cloud.google.com/vertex-ai/docs/training/monitor-debug-interactive-shell) for further investigation from within the job.

```bash
terraform apply
```

If you would like to learn how to submit Vertex AI Training and Pipelines Jobs via the SDK or REST API refer to the following resources:

* [PSC Interface Vertex AI Job Submission](https://github.com/jbrache/vertex-ai-things/blob/main/codelabs/training-psc-interface-proxy/psc_interface_vertex_ai_job_submission.ipynb)
* [Create a custom training job with a Private Service Connect interface](https://cloud.google.com/vertex-ai/docs/training/psc-i-egress)
* [Create a pipeline run with Private Service Connect interfaces](https://cloud.google.com/vertex-ai/docs/pipelines/configure-private-service-connect)

> [!NOTE] 
> **Note:** Upon the initial run, Vertex AI Training jobs may take up to 15 minutes to complete after the last cell has been executed. Its status can be monitored by navigating to the following:
> 
> Vertex AI → Training → Custom jobs - [Cloud Console Link](https://console.cloud.google.com/vertex-ai/training/custom-jobs)

## Files

-   **main.tf**: Main Terraform configuration.
-   **variables.tf**: Variable definitions.
-   **outputs.tf**: Output values.
-   **terraform.tfvars**: Your variable values.

## Cleanup

> [!NOTE]
> **Note:** You can delete the PSC Network Attachment and subnet once Vertex AI Training has not been used for at least one hour.

**Preferred method**

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
