# Gemini Enterprise CMEK Setup - Terraform Guide

This guide automates Customer-Managed Encryption Keys (CMEK) setup for **Gemini Enterprise** (Vertex AI Search) and **Google Cloud Storage (GCS)** using Terraform.

## What This Does

1. Enables required Google Cloud APIs 
    * `cloudkms.googleapis.com`
    * `storage.googleapis.com`
    * `discoveryengine.googleapis.com`
    * `cloudresourcemanager.googleapis.com`
2. Creates Cloud KMS Key Ring and Key in Multi-Region (`us` or `eu`)
3. Creates GCS Bucket with CMEK encryption
4. Grants IAM permissions to service agents
    * `roles/cloudkms.cryptoKeyEncrypterDecrypter`
    * `roles/storage.objectViewer`
    * `roles/storage.admin` (Optional)
5. Registers KMS key with Discovery Engine for new Data Stores
6. Optionally creates Discovery Engine Data Store and imports documents
7. Optionally creates Gemini Enterprise Engine

## Prerequisites

* **Terraform** >= 1.0
* **Google Cloud SDK** installed and authenticated
* **IAM Permissions**: `roles/owner` or equivalent for API enablement and resource creation
* **Gemini Enterprise Edition** enabled for your project

## Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
project_id  = "your-project-id"
bucket_name = "your-unique-bucket-name"  # Must be globally unique
location    = "us"                       # or "eu" (Multi-Region required)

# Optional: Control resource creation
create_data_store               = true   # Create data store via Terraform
create_gemini_enterprise_engine = true   # Create search engine
grant_ge_sa_storage_admin       = true   # Grant Storage Admin to Discovery Engine SA
```

### 2. Authenticate and Initialize

```bash
export PROJECT_ID="your-project-id"
export GOOGLE_PROJECT=$PROJECT_ID
export USER_PROJECT_OVERRIDE=true
export GOOGLE_USE_DEFAULT_CREDENTIALS=true

gcloud config set project $PROJECT_ID
gcloud auth application-default login
gcloud auth application-default set-quota-project $PROJECT_ID

terraform init
```

### 3. Deploy

```bash
terraform plan   # Review changes
terraform apply  # Deploy (confirm with 'yes')
```

### 4. View Results

```bash
terraform output              # All outputs
terraform output next_steps   # Deployment guide
```

## Important Notes

### ⏱️ CMEK Registration Wait Time

**Wait 20 minutes** after CMEK registration before creating Data Stores. The configuration includes a 20-minute wait (`1200s`) by default. If you encounter `INITIALIZING` errors, the CMEK config hasn't propagated yet so retry with a `terraform apply`.
```bash
The location-level TP for `projects/123456789012/locations/us` is not READY; current state is INITIALIZING."
```

### 🔐 Multi-Region Requirement

Gemini Enterprise CMEK **requires Multi-Region keys** (`us` or `eu`). Single regions (e.g., `us-central1`) are **not supported**.

### 🔄 Key Rotation

Automatic key rotation is **disabled** by default to prevent indexing interruptions. Keys have `prevent_destroy = true` for safety.

To enable rotation, edit `main.tf`:
```hcl
rotation_period = "7776000s"  # 90 days
```

### 🔄 Data Connector Synchronization/Import

When `create_data_store = true`, documents from the GCS bucket are automatically imported using a `local-exec` provisioner. Monitor the import status in the Discovery Engine console.

**Wait for the data connector to be ready** before triggering manual synchronization. The connector needs time to complete initialization after creation. If you attempt to sync too early, you may encounter:

```json
{
  "code": 400,
  "message": "Manual Sync is not supported while connector is creating. Please try again later."
  "status": "FAILED_PRECONDITION",
  "details": [
    {
      "@type": "type.googleapis.com/google.rpc.DebugInfo",
      "detail": "Cannot start manual sync for connector projects/123456789012/locations/us/collections/tf-collection-id/dataConnector because it is in state 1"
    }
  ]
}
```

The Terraform configuration includes a 5-minute wait after data connector creation, but complex setups may require additional time. If you encounter this error, wait a few minutes and retry the sync operation.

## Configuration Variables

### Required
- `project_id` - Google Cloud project ID
- `bucket_name` - Globally unique GCS bucket name

### Optional (with defaults)
- `location` - Multi-region location: `"us"` or `"eu"` (default: `"us"`)
- `key_ring_name` - KMS key ring name (default: `"gemini-enterprise-keyring"`)
- `key_name` - KMS crypto key name (default: `"gemini-search-key"`)
- `create_data_store` - Create data store (default: `false`)
- `create_gemini_enterprise_engine` - Create search engine (default: `false`)
- `grant_ge_sa_storage_admin` - Grant Storage Admin role (default: `true`)
- `enable_apis` - Enable required APIs (default: `true`)

See `variables.tf` for complete list and descriptions.

## Verification

### Verify CMEK Configuration
```bash
curl -X GET \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "$(terraform output -raw cmek_config_api_endpoint)"
```

### Verify GCS Bucket Encryption
```bash
gsutil kms encryption gs://$(terraform output -raw bucket_name)
```

### Check Discovery Engine
Navigate to Gemini Enterprise console and verify Data Stores use your CMEK key.

## Troubleshooting

### API Not Enabled
```bash
gcloud services enable cloudkms.googleapis.com storage.googleapis.com discoveryengine.googleapis.com
terraform apply
```

### Permission Errors
Verify your account has required IAM roles:
```bash
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL"
```

### CMEK Registration Fails with "INITIALIZING"
Wait 20 minutes after CMEK registration. The configuration includes this wait time automatically.

### Data Store Creation Fails
Ensure `create_data_store = true` is set after the 15-minute CMEK wait period.

## Cleanup

```bash
terraform destroy  # Review carefully before confirming
```

**Note:** KMS crypto key has `prevent_destroy = true`. Remove this in `main.tf` to destroy the key.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Google Cloud Project                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐         ┌─────────────────────┐           │
│  │   Cloud KMS  │────────>│   GCS Bucket        │           │
│  │   Key Ring   │  CMEK   │   (Encrypted)       │           │
│  │   & Key      │         │                     │           │
│  └──────────────┘         └─────────────────────┘           │
│         │                          │                        │
│         │                          │                        │
│         └──────────────────────────┴─────────────>          │
│                                         │                   │
│                              ┌──────────▼──────────┐        │
│                              │  Discovery Engine   │        │
│                              │  Data Store         │        │
│                              │  (CMEK Encrypted)   │        │
│                              └─────────────────────┘        │
│                                         │                   │
│                              ┌──────────▼──────────┐        │
│                              │  Search Engine      │        │
│                              │  (Gemini Enterprise)│        │
│                              └─────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## References

- [Vertex AI Search: CMEK Documentation](https://docs.cloud.google.com/gemini/enterprise/docs/cmek)
- [Cloud Storage: Customer-Managed Encryption Keys](https://cloud.google.com/storage/docs/encryption/using-customer-managed-keys)
- [Cloud KMS Documentation](https://cloud.google.com/kms/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)

## License

Copyright 2025 Google LLC. Licensed under the Apache License, Version 2.0.

## Disclaimer

This repository is not an officially supported Google product. The code is for demonstrative purposes only.
