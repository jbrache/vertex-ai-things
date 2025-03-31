```
# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
```

# Vertex Training VPC SC Testing

| Author(s) |
| --- |
| [Jose Brache](https://github.com/jbrache) |

## Overview

You can configure [Vertex AI to peer with Virtual Private Cloud](https://cloud.google.com/vertex-ai/docs/general/vpc-peering) (VPC) to connect directly with certain resources in Vertex AI.

This guide shows how to set up the Vertex AI [Interactive Shell](https://cloud.google.com/vertex-ai/docs/training/monitor-debug-interactive-shell) with VPC-SC and VPC Peering. A pre-requisite is setting up VPC Network Peering in a VPC Host Project to peer your network with Vertex AI Training. This guide is recommended for networking administrators who are already familiar with Google Cloud networking concepts.

Review the public docs for the latest information on support:
- [Set up VPC Network Peering for certain Vertex AI resources](https://cloud.google.com/vertex-ai/docs/general/vpc-peering)
- [Set up Connectivity from Vertex AI to Other Networks](https://cloud.google.com/vertex-ai/docs/general/hybrid-connectivity)
- [Setting up a Ray Dashboard and Interactive Shell with VPC-SC + VPC Peering](https://cloud.google.com/vertex-ai/docs/open-source/ray-on-vertex-ai/create-cluster#workaround)

This example covers the following steps:
1. Pre-Requisite: Setup VPC Network Peering with Vertex AI Training, see [this](https://github.com/jbrache/vertex-ai-things/blob/main/MLOps/Training/Vertex_Training_with_VPC_Network_Peering.ipynb) sample.
2. 
8. Clean Up

# 0-0. Set Google Cloud project information

To get started using Vertex AI, you must have an existing Google Cloud project and [enable the Vertex AI API](https://console.cloud.google.com/flows/enableapi?apiid=aiplatform.googleapis.com).

Learn more about [setting up a project and a development environment](https://cloud.google.com/vertex-ai/docs/start/cloud-environment).

```bash
gcloud organizations list
```

```bash
export ORGANIZATION_ID='[Your-Orgainization-ID]' # Example: If your organization ID is 280712296376, replace [Your-Orgainization-ID] with 280712296376
export POLICY_TITLE='[your_vpcsc_folder_perimeter]' # This is the title for the access policy you are creating. You can name it anything that makes sense for your use case.
export SCOPE='folders/012345678901' # This is the scope for the access policy. In this case, it is a folder with ID 012345678901. Adjust this to your specific folder or resource.
export POLICY='accessPolicies/012345678901' # This is the identifier for the access policy you are creating. It should match the policy created in Step #2.
export PRINCIPAL='user:[Your-User-Account]' # This is the user or service account that will have access to the access policy.
export ROLE='roles/accesscontextmanager.policyAdmin'
export PROJECT_ID='[Your-Project-ID]' # Project ID of the project where you want to enable services and create the perimeter. Replace it with your actual project ID.
export PROJECT_NUMBER='[Your-Project-Number]' # Project Number of the project
export VPC_NETWORK_NAME="vertex-vpc-prod"
```

```bash
gcloud config set project $PROJECT_ID
```

# 1-0. Create and Enforce VPC-SC Perimeter

## 1-1. Create Access Context Manager Policy
```bash
gcloud access-context-manager policies create \
  --organization $ORGANIZATION_ID --scopes=$SCOPE --title $POLICY_TITLE
```

Add IAM Binding to user
```bash
gcloud access-context-manager policies add-iam-policy-binding \
  $POLICY --member=$PRINCIPAL --role=$ROLE
```

## 1-2. Create Perimeter in scope project

Public docs reference: [create-service-perimeters](https://cloud.google.com/vpc-service-controls/docs/create-service-perimeters#create-perimeter)

```bash
export PERIMETER_NAME='ai_ml_perimeter'
export TITLE='AI_ML_Perimeter'
export TYPE='regular'
export RESOURCES="projects/${PROJECT_NUMBER},//compute.googleapis.com/projects/${PROJECT_ID}/global/networks/${VPC_NETWORK_NAME}"
export RESTRICTED_SERVICES='storage.googleapis.com,bigquery.googleapis.com,aiplatform.googleapis.com,artifactregistry.googleapis.com'
export RESTRICTED_SERVICES="${RESTRICTED_SERVICES},servicenetworking.googleapis.com"
export POLICY='012345678901' # This should match the policy created in Step 1.
```

```bash
gcloud access-context-manager perimeters dry-run create $PERIMETER_NAME \
  --perimeter-title=$TITLE \
  --perimeter-type=$TYPE \
  --perimeter-resources=$RESOURCES \
  --perimeter-restricted-services=$RESTRICTED_SERVICES \
  --perimeter-ingress-policies=ingress.yaml \
  --perimeter-egress-policies=egress.yaml \
  --policy=$POLICY
```

## 1-3. Enforce the Dry-Run Configuration

Public docs reference: [manage-dry-run-configurations#enforce-configuration](https://cloud.google.com/vpc-service-controls/docs/manage-dry-run-configurations#enforce-configuration)
```bash
gcloud access-context-manager perimeters dry-run enforce $PERIMETER_NAME \
  --policy=$POLICY
```

Public docs reference: [manage-dry-run-configurations#identifying_blocked_requests](https://cloud.google.com/vpc-service-controls/docs/manage-dry-run-configurations#identifying_blocked_requests)
```bash
gcloud logging read 'log_id("cloudaudit.googleapis.com/policy") AND severity="error" AND protoPayload.metadata.dryRun="true"'
```

## 1-4. [Optional] Update the Perimeter (if needed)
```bash
gcloud access-context-manager perimeters update $PERIMETER_NAME \
  --title=$TITLE \
  --type=$TYPE \
  --set-resources=$RESOURCES \
  --set-restricted-services=$RESTRICTED_SERVICES \
  --set-ingress-policies=ingress.yaml \
  --set-egress-policies=egress.yaml \
  --policy=$POLICY
```

## 1-5. Need to enable VPC Service Controls for the peering connection
```bash
gcloud services vpc-peerings enable-vpc-service-controls \
    --project ${PROJECT_ID} \
    --network ${VPC_NETWORK_NAME} \
    --service=servicenetworking.googleapis.com
```

```bash
# For disabling the above
# gcloud services vpc-peerings disable-vpc-service-controls \
#     --project ${PROJECT_ID} \
#     --network ${VPC_NETWORK_NAME} \
#     --service=servicenetworking.googleapis.com
```

# 2-0. Interactive Shell with VPC-SC + VPC Peering

View [this guide for how to do this for Ray on Vertex AI](https://cloud.google.com/vertex-ai/docs/open-source/ray-on-vertex-ai/create-cluster#workaround), but it applies for Vertex AI Custom Jobs too.

## 2-1. Configure peered-dns-domains

```bash
export REGION="us-central1"
```

```bash
gcloud services peered-dns-domains create aiplatform-training-cloud \
    --project ${PROJECT_ID} \
    --network=${VPC_NETWORK_NAME} \
    --dns-suffix=${REGION}.aiplatform-training.cloud.google.com.
```

```bash
# Verify
gcloud beta services peered-dns-domains list --network ${VPC_NETWORK_NAME}
```

## 2-2. Configure DNS managed zone

```bash
export ZONE_NAME="${PROJECT_ID}-aiplatform-training-cloud-google-com"
export DNS_NAME="aiplatform-training.cloud.google.com"
export DESCRIPTION="aiplatform-training.cloud.google.com"
```

```bash
gcloud dns managed-zones create ${ZONE_NAME}  \
    --project ${PROJECT_ID} \
    --visibility=private \
    --networks=https://www.googleapis.com/compute/v1/projects/${PROJECT_ID}/global/networks/${VPC_NETWORK_NAME} \
    --dns-name=$DNS_NAME \
    --description="Training ${DESCRIPTION}"
```

## 2-3. Record DNS transaction

```bash
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
```

# 3-0. Run custom training jobs on the Peered VPC

Pre-Requisite: Setup VPC Network Peering with Vertex AI Training, see [this](https://github.com/jbrache/vertex-ai-things/blob/main/MLOps/Training/Vertex_Training_with_VPC_Network_Peering.ipynb) sample.

## 3-1. Prepare training jobs

Vertex AI Training supports submiting custom training jobs with a prebuilt container, custom container and python application via **HTTP request, Vertex AI SDK or gcloud CLI**. Learn more [here](https://cloud.google.com/vertex-ai/docs/training/code-requirements).

In this example, we will demonstrate how to run a custom job with with custom containers. Please specify the images below to your custom images.
Note, if it's not a public image, please ensure it's already pushed to your project.

https://cloud.google.com/vertex-ai/docs/training/containers-overview

Edit your job spec YAML, see [custom_job_spec.yaml](custom_job_spec.yaml) as an example.

## 3-2. Create CPU test job on Vertex AI Training

```bash
#----------- Create CPU Test Job -----------#
!gcloud beta ai custom-jobs create \
    --project=${PROJECT_ID} \
    --region=${REGION} \
    --display-name="CPU Test Job Peering" \
    --config=custom_job_spec.yaml \
    --enable-web-access \
    --labels network_type=vpc_peering
```

## 3-3. Monitor and debug training with an interactive shell

The jobs in this project have [enabled interactive shells](https://cloud.google.com/vertex-ai/docs/training/monitor-debug-interactive-shell) for the custom training resource. The interactive shell allows you to inspect the container where your training code is running.

You can navigate to the interactive shell with [these](https://cloud.google.com/vertex-ai/docs/training/monitor-debug-interactive-shell#navigate-console) instructions.

# 4-0. Get Job Details

```bash
# Option 1: Use the Custom Job ID to get details
# JOB_ID = "" # @param {type:"string"}
# !gcloud beta ai custom-jobs describe {JOB_ID} --project={PROJECT_ID} --region={REGION}
```

```bash
# Option 2: List existing custom jobs, filter running jobs and ones with the set label
# Lists the existing custom jobs, filters with the label set for these jobs
FILTER = '"(state!="JOB_STATE_SUCCEEDED" AND state!="JOB_STATE_FAILED" AND state!="JOB_STATE_CANCELLED") AND labels.network_type=vpc_peering"'
!gcloud beta ai custom-jobs list --project={PROJECT_ID} --region={REGION} --filter={FILTER}
```

# 5-0. Cleaning up

To clean up all Google Cloud resources used in this project, you can [delete the Google Cloud
project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#shutting_down_projects) you used for the tutorial.

Otherwise, you can delete the individual resources you created in this tutorial:

- VPC-SC Perimeter
- DNS Records
