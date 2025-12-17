# Gemini Enterprise CMEK Setup - Terraform Guide

This guide explains how to set up Customer-Managed Encryption Keys (CMEK) for **Gemini Enterprise** (Vertex AI Search) and **Google Cloud Storage (GCS)** using Terraform.

## Overview

The Terraform configuration automates the following:

1. Enables required Google Cloud APIs (`cloudkms`, `storage`, `discoveryengine`)
2. Creates a **Cloud KMS Key Ring** and **Key** in a Multi-Region location (`us` or `eu`)
3. Creates a **GCS Bucket** with CMEK encryption
4. Grants necessary IAM permissions to service agents
5. Registers the KMS key with **Discovery Engine API** for new Data Stores
6. Optionally creates a Discovery Engine Data Store

## Prerequisites

Before using this Terraform configuration, ensure you have:

* **Terraform** >= 1.0 installed
* **Google Cloud SDK (`gcloud`)** installed and authenticated
* **IAM Permissions**:
  * `roles/owner` or `roles/editor` (to enable APIs and create resources)
  * `roles/resourcemanager.projectIamAdmin` (to grant Service Agent permissions)
  * `roles/discoveryengine.admin` (to configure Gemini Enterprise settings)
* **Gemini Enterprise Edition** enabled for your project

## Terraform Files

The configuration includes:

- **`main.tf`** - Main infrastructure configuration
- **`variables.tf`** - Input variable definitions with validation
- **`outputs.tf`** - Output values including next steps
- **`terraform.tfvars.example`** - Example variable values

## Quick Start

### 1. Navigate to the Directory

```bash
cd gen-ai/gemini-enterprise/ge-gcs-cmek-setup
```

### 2. Copy and Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your project details:

```hcl
# Required: Your Google Cloud project ID
project_id = "your-project-id"

# Required: Globally unique name for the GCS bucket
bucket_name = "your-unique-bucket-name"

# Multi-Region location (must be 'us' or 'eu' for Gemini Enterprise CMEK)
location = "us"

# Optional: Customize KMS key names
key_ring_name = "gemini-enterprise-keyring"
key_name = "gemini-search-key"

# Optional: Enable API activation via Terraform
enable_apis = true

# Optional: Create data store (set to false to create manually after 15min wait)
create_data_store = false
```

### 3. Initialize Terraform

Set these environment variables, and application-default credentials first.
```bash
export PROJECT_ID="your-project-id"
export PROJECT_ID="ge-thunderdome-jb02"
export GOOGLE_PROJECT=$PROJECT_ID
export USER_PROJECT_OVERRIDE=true
export GOOGLE_USE_DEFAULT_CREDENTIALS=true

gcloud config set project $PROJECT_ID
gcloud auth application-default login
gcloud auth application-default set-quota-project $PROJECT_ID
```

```bash
terraform init
```

### 4. Review the Execution Plan

```bash
terraform plan
```

Review the resources that will be created:
- KMS Key Ring and Crypto Key
- GCS Bucket with CMEK
- IAM policy bindings
- Discovery Engine CMEK configuration

### 5. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 6. Review Outputs

After successful deployment, view the outputs:

```bash
terraform output
```

For detailed next steps:

```bash
terraform output next_steps
```

## Important Configuration Details

### Multi-Region Requirement

Gemini Enterprise CMEK **requires Multi-Region keys**. The configuration validates that `location` is either `us` or `eu`. Single regions (e.g., `us-central1`) are not supported.

### Key Rotation

Per Vertex AI Search documentation, the configuration does **not** enable automatic key rotation to avoid indexing interruptions. Keys are set with `prevent_destroy = true` for safety.

If you want to enable rotation, edit `main.tf` and uncomment:

```hcl
rotation_period = "7776000s"  # 90 days
```

### Discovery Engine CMEK Registration

The configuration uses `null_resource` with `local-exec` to call the Discovery Engine API because Terraform doesn't have native support for this resource yet.

**Important:** Wait **15 minutes** after applying before creating new Data Stores to allow the CMEK configuration to propagate.

### Data Store Creation

By default, `create_data_store = false` because of the required 15-minute wait time. You have two options:

1. **Recommended:** Create the Data Store manually after waiting 15 minutes
2. Set `create_data_store = true` and run `terraform apply` again after 15 minutes

## Verification

### 1. Verify CMEK Configuration

Use the API endpoint from outputs:

```bash
curl -X GET \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "$(terraform output -raw cmek_config_api_endpoint)"
```

### 2. Verify GCS Bucket Encryption

In the Cloud Console:
1. Navigate to Cloud Storage
2. Select your bucket
3. Go to the **Configuration** tab
4. Verify **Encryption type** shows your KMS key

Or via CLI:

```bash
gsutil kms encryption gs://$(terraform output -raw bucket_name)
```

### 3. Create and Verify a Data Store

After waiting 15 minutes, create a new Data Store in the Gemini Enterprise console. Verify it automatically uses your CMEK key.

## Terraform Commands Reference

```bash
# Initialize Terraform
terraform init

# Format configuration files
terraform fmt

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List outputs
terraform output

# View specific output
terraform output next_steps

# Destroy infrastructure (use with caution!)
terraform destroy
```

## Variables Reference

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `project_id` | string | Yes | - | Google Cloud project ID |
| `bucket_name` | string | Yes | - | Globally unique GCS bucket name |
| `location` | string | No | `"us"` | Multi-region location (`us` or `eu`) |
| `key_ring_name` | string | No | `"gemini-enterprise-keyring"` | KMS key ring name |
| `key_name` | string | No | `"gemini-search-key"` | KMS crypto key name |
| `bucket_storage_class` | string | No | `"STANDARD"` | GCS bucket storage class |
| `collection_id` | string | No | `"gcs-cmek-datastore-api"` | Discovery Engine collection ID |
| `collection_display_name` | string | No | `"gcs-cmek-datastore-api"` | Collection display name |
| `data_store_display_name` | string | No | `"gcs-cmek-datastore-api"` | Data store display name |
| `create_data_store` | bool | No | `false` | Create Data Store via Terraform |
| `enable_apis` | bool | No | `true` | Enable required APIs |

## Outputs Reference

| Output | Description |
|--------|-------------|
| `project_id` | The Google Cloud project ID |
| `project_number` | The Google Cloud project number |
| `location` | Multi-region location used |
| `kms_key_ring_id` | KMS key ring resource ID |
| `kms_crypto_key_id` | KMS crypto key resource ID |
| `bucket_name` | GCS bucket name |
| `bucket_url` | GCS bucket URL |
| `gcs_service_agent` | GCS service agent email |
| `discovery_engine_service_agent` | Discovery Engine service agent email |
| `cmek_config_api_endpoint` | API endpoint to verify CMEK config |
| `next_steps` | Detailed next steps after deployment |

## Troubleshooting

### API Not Enabled Error

If you see errors about APIs not being enabled:

```bash
# Manually enable APIs
gcloud services enable cloudkms.googleapis.com storage.googleapis.com discoveryengine.googleapis.com --project=YOUR_PROJECT_ID

# Then retry Terraform apply
terraform apply
```

### Permission Denied Errors

Ensure your account has the required IAM roles:

```bash
# Check your permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:user:YOUR_EMAIL"
```

### Data Store Creation Fails

Remember to wait **15 minutes** after CMEK registration before creating Data Stores. If you set `create_data_store = true` too early, wait and run:

```bash
terraform apply -replace=null_resource.create_discovery_engine_collection[0]
```

### Bucket Already Exists

If the bucket name is taken, update `bucket_name` in `terraform.tfvars` with a globally unique name and run `terraform apply` again.

## Cleaning Up

To destroy all created resources:

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy (use with caution!)
terraform destroy
```

**Note:** The KMS crypto key has `prevent_destroy = true` to prevent accidental deletion. To destroy it, you must first remove this protection in `main.tf`.

## References

* [Terraform Google Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
* [Vertex AI Search: Customer-managed encryption keys (CMEK)](https://docs.cloud.google.com/gemini/enterprise/docs/cmek)
* [Cloud Storage: Using Customer-Managed Encryption Keys](https://cloud.google.com/storage/docs/encryption/using-customer-managed-keys)
* [Cloud KMS Documentation](https://cloud.google.com/kms/docs)

## License

Copyright 2025 Google LLC. Licensed under the Apache License, Version 2.0.

## Disclaimer

This repository itself is not an officially supported Google product. The code in this repository is for demonstrative purposes only.
