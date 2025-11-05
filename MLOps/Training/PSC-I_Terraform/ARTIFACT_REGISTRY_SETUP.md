# Artifact Registry Setup for Vertex AI Training

## Overview

This document describes the Artifact Registry configuration added to the Terraform setup for storing Docker container images used in Vertex AI training jobs.

## Manual Creation (Already Done)

The repository `vertex-training-test` was manually created in the `ds-dev-jb0001` project:

```bash
gcloud artifacts repositories create vertex-training-test \
  --repository-format=docker \
  --location=us \
  --description="Vertex AI training test repository"
```

**Repository Details:**
- **Name:** vertex-training-test
- **Location:** us (multi-region)
- **Format:** DOCKER
- **Registry URI:** us-docker.pkg.dev/ds-dev-jb0001/vertex-training-test
- **Created:** 2025-11-05T15:43:11.367293Z

## Terraform Configuration

The Terraform configuration now includes automated creation of Artifact Registry repositories in each Vertex AI service project.

### New Variables

The following variables were added to `variables.tf`:

```hcl
variable "create_artifact_registry" {
  description = "Enable creation of Artifact Registry repository for Vertex AI training containers"
  type        = bool
  default     = true
}

variable "artifact_registry_repository_id" {
  description = "The ID of the Artifact Registry repository to create"
  type        = string
  default     = "vertex-training-test"
}

variable "artifact_registry_location" {
  description = "The location for the Artifact Registry repository (e.g., 'us' for multi-region)"
  type        = string
  default     = "us"
}

variable "artifact_registry_description" {
  description = "Description for the Artifact Registry repository"
  type        = string
  default     = "Vertex AI training test repository"
}

variable "artifact_registry_format" {
  description = "The format of the Artifact Registry repository"
  type        = string
  default     = "DOCKER"
}
```

### Resources Added

1. **API Enablement:** Enables the Artifact Registry API in all service projects
2. **Repository Creation:** Creates an Artifact Registry repository in each Vertex AI service project

### Outputs Added

The `artifact_registry_repositories` output provides details about created repositories:

```hcl
output "artifact_registry_repositories" {
  description = "Map of Vertex AI service project IDs to their Artifact Registry repository details"
  value = {
    for project_id in var.vertex_ai_service_project_ids :
    project_id => {
      repository_id = ...
      location      = ...
      format        = ...
      name          = ...
      registry_uri  = ...
    }
  }
}
```

## Usage

### Pushing Images to the Repository

To push a Docker image to the Artifact Registry:

```bash
# Tag your image
docker tag <image> us-docker.pkg.dev/ds-dev-jb0001/vertex-training-test/<image-name>:<tag>

# Configure Docker authentication
gcloud auth configure-docker us-docker.pkg.dev

# Push the image
docker push us-docker.pkg.dev/ds-dev-jb0001/vertex-training-test/<image-name>:<tag>
```

### Using in Vertex AI Training Jobs

Reference the container image in your Vertex AI training job configuration:

```yaml
workerPoolSpecs:
- machineSpec:
    machineType: n1-standard-4
  replicaCount: 1
  containerSpec:
    imageUri: us-docker.pkg.dev/ds-dev-jb0001/vertex-training-test/my-trainer:latest
```

Or via gcloud:

```bash
gcloud ai custom-jobs create \
  --project=ds-dev-jb0001 \
  --region=us-central1 \
  --display-name=my-training-job \
  --worker-pool-spec=machine-type=n1-standard-4,replica-count=1,container-image-uri=us-docker.pkg.dev/ds-dev-jb0001/vertex-training-test/my-trainer:latest
```

## Configuration Options

You can customize the Artifact Registry setup in `terraform.tfvars`:

```hcl
# Enable or disable Artifact Registry creation
create_artifact_registry = true

# Customize repository settings
artifact_registry_repository_id = "vertex-training-test"
artifact_registry_location = "us"
artifact_registry_description = "Vertex AI training test repository"
artifact_registry_format = "DOCKER"
```

## Terraform Commands

To apply the Terraform configuration:

```bash
cd MLOps/Training/PSC-I_Terraform

# Preview changes
terraform plan

# Apply changes
terraform apply

# View outputs
terraform output artifact_registry_repositories
```

## Notes

- The repository is created in each Vertex AI service project specified in `vertex_ai_service_project_ids`
- The `us` multi-region location provides high availability and low latency across US regions
- The Artifact Registry API must be enabled in each project (handled automatically by Terraform)
- Repository names must be unique within a project and location
