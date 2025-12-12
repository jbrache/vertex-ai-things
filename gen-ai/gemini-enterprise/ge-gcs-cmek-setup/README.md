# Gemini Enterprise CMEK Setup
This repository contains a shell script to automate the setup of Customer-Managed Encryption Keys (CMEK) for **Gemini Enterprise** (Vertex AI Search) and a **Google Cloud Storage (GCS)** bucket.

This script ensures that both your source data (in GCS) and your indexed data (in Gemini/Discovery Engine) are protected by keys you control in Cloud KMS.

## Overview
The `setup_gemini_cmek.sh` script performs the following actions:

1. Enables required Google Cloud APIs (`cloudkms`, `storage`, `discoveryengine`).
2. Creates a **Cloud KMS Key Ring** and **Key** in a Multi-Region location (`us` or `eu`).
3. Creates a **GCS Bucket** and enforces the default encryption key to be your new KMS key.
4. Grants the necessary `CryptoKey Encrypter/Decrypter` IAM roles to:
  * The Cloud Storage Service Agent.
  * The Discovery Engine (Gemini) Service Agent.
5. Registers the KMS key with the **Discovery Engine API** so that future Data Stores use this key by default.

## Prerequisites  
Before running this script, ensure you have the following:

* **Google Cloud SDK (`gcloud`)** installed and authenticated.
* **`curl`** installed (used for the Discovery Engine API call).
* **IAM Permissions**:
  * `roles/owner` or `roles/editor` (to enable APIs and create resources).
  * `roles/resourcemanager.projectIamAdmin` (to grant Service Agent permissions).
  * `roles/discoveryengine.admin` (to configure Gemini Enterprise settings).
* **Gemini Enterprise Edition**: Ensure Enterprise Edition is enabled for your project.

## Configuration
Open `setup_gemini_cmek.sh` and modify the following variables at the top of the file to match your environment:

```bash
PROJECT_ID="your-project-id"
LOCATION="us"              # Must be 'us' or 'eu' (Multi-Region) for Gemini Ent.
KEY_RING_NAME="gemini-enterprise-keyring"
KEY_NAME="gemini-search-key"
BUCKET_NAME="your-gemini-data-bucket"

```

> **Warning:** Gemini Enterprise CMEK requires **Multi-Region** keys. Set `LOCATION` to `us` or `eu`. Single regions (e.g., `us-central1`) are often not supported for the search index CMEK.

## Usage
1. **Save the script** to a file named `setup_gemini_cmek.sh`.
2. **Make the script executable**:
```bash
chmod +x setup_gemini_cmek.sh
```
3. **Run the script**:
```bash
./setup_gemini_cmek.sh
```

## The Script
```bash
#!/bin/bash

# ==============================================================================
# Configuration Variables
# ==============================================================================
PROJECT_ID="your-project-id"
LOCATION="us" 
KEY_RING_NAME="gemini-enterprise-keyring"
KEY_NAME="gemini-search-key"
BUCKET_NAME="your-gemini-data-bucket"

# ==============================================================================
# 1. Setup Environment & Enable APIs
# ==============================================================================
echo "Setting project to $PROJECT_ID..."
gcloud config set project "$PROJECT_ID"

echo "Enabling required APIs..."
gcloud services enable \
    cloudkms.googleapis.com \
    storage.googleapis.com \
    discoveryengine.googleapis.com

# Get Project Number (required for Service Agent emails)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
echo "Project Number: $PROJECT_NUMBER"

# ==============================================================================
# 2. Create Cloud KMS Key Ring and Key
# ==============================================================================
echo "Creating KMS Key Ring in $LOCATION..."
if ! gcloud kms keyrings describe "$KEY_RING_NAME" --location "$LOCATION" > /dev/null 2>&1; then
    gcloud kms keyrings create "$KEY_RING_NAME" --location "$LOCATION"
else
    echo "Key Ring $KEY_RING_NAME already exists."
fi

echo "Creating KMS Key..."
if ! gcloud kms keys describe "$KEY_NAME" --keyring "$KEY_RING_NAME" --location "$LOCATION" > /dev/null 2>&1; then
    gcloud kms keys create "$KEY_NAME" \
        --keyring "$KEY_RING_NAME" \
        --location "$LOCATION" \
        --purpose "encryption" \
        --rotation-period "30d" \
        --next-rotation-time "2026-01-01T00:00:00"
else
    echo "Key $KEY_NAME already exists."
fi

KEY_RESOURCE_NAME="projects/$PROJECT_ID/locations/$LOCATION/keyRings/$KEY_RING_NAME/cryptoKeys/$KEY_NAME"
echo "Key Resource Name: $KEY_RESOURCE_NAME"

# ==============================================================================
# 3. Create GCS Bucket and Enable CMEK
# ==============================================================================
echo "Creating GCS Bucket: $BUCKET_NAME..."
gcloud storage buckets create "gs://$BUCKET_NAME" \
    --location "$LOCATION" \
    --default-storage-class=STANDARD \
    --uniform-bucket-level-access \
    --public-access-prevention

echo "Setting default CMEK for GCS Bucket..."
gcloud storage buckets update "gs://$BUCKET_NAME" \
    --default-encryption-key "$KEY_RESOURCE_NAME"

# ==============================================================================
# 4. Grant Permissions (IAM)
# ==============================================================================
echo "Granting permissions to Service Agents..."

# GCS Service Agent
GCS_SERVICE_AGENT="service-$PROJECT_NUMBER@gs-project-accounts.iam.gserviceaccount.com"

gcloud kms keys add-iam-policy-binding "$KEY_NAME" \
    --keyring "$KEY_RING_NAME" \
    --location "$LOCATION" \
    --member "serviceAccount:$GCS_SERVICE_AGENT" \
    --role "roles/cloudkms.cryptoKeyEncrypterDecrypter"

# Discovery Engine (Gemini) Service Agent
DISCOVERY_ENGINE_SERVICE_AGENT="service-$PROJECT_NUMBER@gcp-sa-discoveryengine.iam.gserviceaccount.com"

gcloud kms keys add-iam-policy-binding "$KEY_NAME" \
    --keyring "$KEY_RING_NAME" \
    --location "$LOCATION" \
    --member "serviceAccount:$DISCOVERY_ENGINE_SERVICE_AGENT" \
    --role "roles/cloudkms.cryptoKeyEncrypterDecrypter"

# ==============================================================================
# 5. Enable CMEK for Gemini Enterprise (Vertex AI Search)
# ==============================================================================
echo "Registering CMEK with Gemini Enterprise (Discovery Engine)..."

API_ENDPOINT="https://$LOCATION-discoveryengine.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/cmekConfigs/default_cmek_config?set_default=true"

curl -X PATCH \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json" \
    -H "x-goog-user-project: $PROJECT_ID" \
    -d "{\"kmsKey\": \"$KEY_RESOURCE_NAME\"}" \
    "$API_ENDPOINT"

echo -e "\nSetup Complete. New Data Stores in $LOCATION will now use your CMEK."

# ==============================================================================
# 6. Create GCS Data Store
# ==============================================================================
export COLLECTION_ID="gcs-cmek-datastore-api"
export COLLECTION_DISPLAY_NAME="gcs-cmek-datastore-api"

# _gcs_store gets automatically appended
export DATA_STORE_ID="gcs-cmek-datastore-api_gcs_store"
export DATA_STORE_DISPLAY_NAME="gcs-cmek-datastore-api"

# Create Collection v2
curl -X POST \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H "Content-Type: application/json" \
-H "X-Goog-User-Project: $PROJECT_ID" \
"https://$LOCATION-discoveryengine.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION:setUpDataConnectorV2?collectionId=$COLLECTION_ID&collectionDisplayName=$COLLECTION_DISPLAY_NAME" \
-d "{
  \"dataSource\": \"gcs\",
  \"refreshInterval\": \"86400s\",
  \"entities\": [
    {
      \"entityName\": \"gcs_store\",
      \"params\": {
        \"content_config\": \"content_required\",
        \"auto_generate_ids\": true,
        \"industry_vertical\": \"generic\",
      }
    }
  ],
  \"params\": {
    \"instance_uris\": [\"gs://$BUCKET_NAME/**\"]
  },
  \"kmsKeyName\": \"$KEY_RESOURCE_NAME\"
}"

# Import docs
curl -X POST \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H "Content-Type: application/json" \
-H "X-Goog-User-Project: $PROJECT_ID" \
"https://$LOCATION-discoveryengine.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/collections/default_collection/dataStores/$DATA_STORE_ID/branches/0/documents:import" \
-d "{
  \"gcsSource\": {
    \"inputUris\": [\"gs://$BUCKET_NAME/*\"],
    \"dataSchema\": \"content\"
  },
  \"reconciliationMode\": \"FULL\",
}"

# Verify that a data store is protected by a key
curl -X GET \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H "Content-Type: application/json" \
-H "x-goog-user-project: $PROJECT_ID" \
"https://$LOCATION-discoveryengine.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/collections/default_collection/dataStores/$DATA_STORE_ID"

# List All Datastores
curl -X GET \
-H "Authorization: Bearer $(gcloud auth print-access-token)" \
-H "Content-Type: application/json" \
-H "x-goog-user-project: $PROJECT_ID" \
"https://$LOCATION-discoveryengine.googleapis.com/v1/projects/$PROJECT_ID/locations/$LOCATION/collections/default_collection/dataStores"
```

## Important Notes
1. **New Resources Only:** Registering the CMEK with Discovery Engine (Step 5) only applies to **new** Data Stores created after the script is run. Existing Data Stores cannot be migrated to CMEK.
2. **Key Rotation:** Vertex AI Search documentation recommends setting the rotation period to "Never" (manual rotation) to avoid indexing interruptions.
3. **Verification:**
* **GCS:** Go to the Cloud Storage Console > Configuration tab for your bucket to see the Encryption Key setting.
* **Gemini:** Create a new Data Store in the console. You should see it automatically associated with your KMS key.

## References
* [Vertex AI Search: Customer-managed encryption keys (CMEK)](https://docs.cloud.google.com/gemini/enterprise/docs/cmek)
* [Cloud Storage: Using Customer-Managed Encryption Keys](https://www.google.com/search?q=https://cloud.google.com/storage/docs/encryption/using-customer-managed-keys)