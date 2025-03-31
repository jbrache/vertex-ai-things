# Step 0: Get organization id, create access policy
gcloud organizations list

export ORGANIZATION_ID='[Your-Orgainization-ID]' # Example: If your organization ID is 280712296376, replace [Your-Orgainization-ID] with 280712296376
export POLICY_TITLE='[your_vpcsc_folder_perimeter]' # This is the title for the access policy you are creating. You can name it anything that makes sense for your use case.
export SCOPE='folders/012345678901' # This is the scope for the access policy. In this case, it is a folder with ID 012345678901. Adjust this to your specific folder or resource.
export POLICY='accessPolicies/012345678901' # This is the identifier for the access policy you are creating. It should match the policy created in Step #2.
export PRINCIPAL='user:[Your-User-Account]' # This is the user or service account that will have access to the access policy.
export ROLE='roles/accesscontextmanager.policyAdmin'
export PROJECT_ID='[Your-Project-ID]' # Project ID of the project where you want to enable services and create the perimeter. Replace it with your actual project ID.
export PROJECT_NUMBER='[Your-Project-Number]' # Project Number of the project
export VPC_NETWORK_NAME="vertex-vpc-prod"


## ------------------------------------------------------------------------
# Step 1 Create the access policy with the specified organization ID and title
gcloud access-context-manager policies create \
  --organization $ORGANIZATION_ID --scopes=$SCOPE --title $POLICY_TITLE

## ------------------------------------------------------------------------
# Step 2 Add IAM Binding to principal in the access policy
gcloud access-context-manager policies add-iam-policy-binding \
  $POLICY --member=$PRINCIPAL --role=$ROLE

## ------------------------------------------------------------------------
# Step 3 Enable Services of in scope project
gcloud config set project $PROJECT_ID
gcloud auth application-default set-quota-project $PROJECT_ID
gcloud services enable aiplatform.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable artifactregistry.googleapis.com
# gcloud services enable cloudbuild.googleapis.com
gcloud services enable servicenetworking.googleapis.com

## ------------------------------------------------------------------------
# Step 3 Create Perimeter in scope project
# https://cloud.google.com/vpc-service-controls/docs/create-service-perimeters#create-perimeter

export PERIMETER_NAME='ai_ml_perimeter'
export TITLE='AI_ML_Perimeter'
export TYPE='regular'
export RESOURCES="projects/${PROJECT_NUMBER},//compute.googleapis.com/projects/${PROJECT_ID}/global/networks/${VPC_NETWORK_NAME}"
export RESTRICTED_SERVICES='storage.googleapis.com,bigquery.googleapis.com,aiplatform.googleapis.com,artifactregistry.googleapis.com'
export RESTRICTED_SERVICES="${RESTRICTED_SERVICES},servicenetworking.googleapis.com"
export POLICY='012345678901' # This should match the policy created in Step 1.

# https://cloud.google.com/vpc-service-controls/docs/create-service-perimeters
gcloud access-context-manager perimeters dry-run create $PERIMETER_NAME \
  --perimeter-title=$TITLE \
  --perimeter-type=$TYPE \
  --perimeter-resources=$RESOURCES \
  --perimeter-restricted-services=$RESTRICTED_SERVICES \
  --perimeter-ingress-policies=ingress.yaml \
  --perimeter-egress-policies=egress.yaml \
  --policy=$POLICY

## ------------------------------------------------------------------------
# Step 4: Enforce the Dry-Run Configuration
# https://cloud.google.com/vpc-service-controls/docs/manage-dry-run-configurations#enforce-configuration
gcloud access-context-manager perimeters dry-run enforce $PERIMETER_NAME \
  --policy=$POLICY

# https://cloud.google.com/vpc-service-controls/docs/manage-dry-run-configurations#identifying_blocked_requests
gcloud logging read 'log_id("cloudaudit.googleapis.com/policy") AND severity="error" AND protoPayload.metadata.dryRun="true"'

## ------------------------------------------------------------------------
# Step 5: Update the Perimeter (if needed)
# https://cloud.google.com/vpc-service-controls/docs/create-service-perimeters
gcloud access-context-manager perimeters update $PERIMETER_NAME \
  --title=$TITLE \
  --type=$TYPE \
  --set-resources=$RESOURCES \
  --set-restricted-services=$RESTRICTED_SERVICES \
  --set-ingress-policies=ingress.yaml \
  --set-egress-policies=egress.yaml \
  --policy=$POLICY

## ------------------------------------------------------------------------
# Step 6: Need to enable VPC Service Controls for the peering connection
gcloud services vpc-peerings enable-vpc-service-controls \
    --project ${PROJECT_ID} \
    --network ${VPC_NETWORK_NAME} \
    --service=servicenetworking.googleapis.com

# For disabling the above
# gcloud services vpc-peerings disable-vpc-service-controls \
#     --project ${PROJECT_ID} \
#     --network ${VPC_NETWORK_NAME} \
#     --service=servicenetworking.googleapis.com
    
## ------------------------------------------------------------------------
# Interactive Shell with VPC-SC + VPC Peering
# https://cloud.google.com/vertex-ai/docs/open-source/ray-on-vertex-ai/create-cluster#workaround
# Step 7: Configure peered-dns-domains.
export REGION="us-central1"

gcloud services peered-dns-domains create aiplatform-training-cloud \
    --project ${PROJECT_ID} \
    --network=${VPC_NETWORK_NAME} \
    --dns-suffix=${REGION}.aiplatform-training.cloud.google.com.

# Verify
gcloud beta services peered-dns-domains list --network ${VPC_NETWORK_NAME}

# Step 8: Configure DNS managed zone.
export ZONE_NAME="${PROJECT_ID}-aiplatform-training-cloud-google-com"
export DNS_NAME="aiplatform-training.cloud.google.com"
export DESCRIPTION="aiplatform-training.cloud.google.com"

gcloud dns managed-zones create ${ZONE_NAME}  \
    --project ${PROJECT_ID} \
    --visibility=private \
    --networks=https://www.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/networks/${VPC_NETWORK_NAME} \
    --dns-name=$DNS_NAME \
    --description="Training ${DESCRIPTION}"

# Step 9: Record DNS transaction.
gcloud dns record-sets transaction start \
    --zone=$ZONE_NAME

gcloud dns record-sets transaction add \
    --project ${PROJECT_ID} \
    --name=$DNS_NAME. \
    --type=A 199.36.153.4 199.36.153.5 199.36.153.6 199.36.153.7 \
    --zone=$ZONE_NAME \
    --ttl=300

gcloud dns record-sets transaction add \
    --project ${PROJECT_ID} \
    --name=*.$DNS_NAME. \
    --type=CNAME $DNS_NAME. \
    --zone=$ZONE_NAME \
    --ttl=300

gcloud dns record-sets transaction execute \
    --project ${PROJECT_ID} \
    --zone=$ZONE_NAME

## ------------------------------------------------------------------------
# Step 10: Create Vertex AI Training Job


