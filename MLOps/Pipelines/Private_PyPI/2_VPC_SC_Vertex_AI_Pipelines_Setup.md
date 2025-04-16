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

# Vertex AI Pipelines: VPC Service Controls and a private Artifact Registry Python repository

| Author(s) |
| --- |
| [Jose Brache](https://github.com/jbrache) |

## Overview

You can configure [Vertex AI with VPC Service Controls](https://cloud.google.com/vertex-ai/docs/general/vpc-service-controls) to create a *service perimeter* that protects the resources and data that you specify.

This guide shows how to set up the Vertex AI with VPC-SC, and run Vertex Pipelines configured to use a private Artifact Registry Python repository to install Python packages at runtime.

This example covers the following steps:
1. Pre-Requisite: Configure Private Artifact Registry: [0_Configure_Private_Artifact_Registry.md](0_Configure_Private_Artifact_Registry.md)
2. Create and Enforce VPC-SC Perimeter
3. Run Vertex AI Pipelines with VPC-SC: [1_Vertex_AI_Pipelines_Introduction.ipynb](1_Vertex_AI_Pipelines_Introduction.ipynb)
4. Summary

This example shows you how to host a private PyPI repository on GCP Artifact Registry and configure VPC-SC to allow Vertex AI Pipelines to access the repository. For production best-practice, adding dependencies into the docker images of Vertex AI Pipelines is recommended, which provides more reliable and repeatable environment and reduces runtime cost.

Sometimes users do favor the flexibility of installing dependencies on the fly. In that case, users can host a private PyPI repository. 

An **alternative approach from this sample** is to provide network egress connectivity for Vertex AI Pipelines to your VPC via **VPC Peering** or **PSC-I** to reach a private PyPI repository:
- [Set up VPC Network Peering for certain Vertex AI resources](https://cloud.google.com/vertex-ai/docs/general/vpc-peering)
- [Configure Private Service Connect interface for a pipeline](https://cloud.google.com/vertex-ai/docs/pipelines/configure-private-service-connect)

# 0-0. Set Google Cloud project information

To get started using Vertex AI, you must have an existing Google Cloud project and [enable the Vertex AI API](https://console.cloud.google.com/flows/enableapi?apiid=aiplatform.googleapis.com).

Learn more about [setting up a project and a development environment](https://cloud.google.com/vertex-ai/docs/start/cloud-environment).

Get your organization ID
```sh
gcloud organizations list
```

```sh
export ORGANIZATION_ID='280712296376' # Example: If your organization ID is 280712296376, replace with your actual organization ID.
export POLICY_TITLE='vpcsc_folder_perimeter' # This is the title for the access policy you are creating. You can name it anything that makes sense for your use case.
export SCOPE='folders/520712946030' # This is the scope for the access policy. In this case, it is a folder with ID 520712946030. Adjust this to your specific folder or resource for your Vertex AI Project.
export PRINCIPAL='ldap@domain.com' # Change this to the user that will have access to the access policy.
export ROLE='roles/accesscontextmanager.policyAdmin' # This role will be granted on the principal
export PROJECT_ID='ds-dev-jb02-pypi' # Project ID of the project where you want to enable services and create the perimeter. Replace it with your actual project ID.
export SERVICE_ACCOUNT_VERTEX="vertex-ai-sa@$PROJECT_ID.iam.gserviceaccount.com" # Use the service account being used for Vertex AI Pipelines
```

```sh
gcloud config set project $PROJECT_ID
```
Set environment variable for Project Number
```sh
export PROJECT_NUMBER="$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")"
```

## 0-1. Enable APIs
The following APIs are enabled in this demo:
1. [Enable the Access Context Manager API](https://console.cloud.google.com/flows/enableapi?apiid=accesscontextmanager.googleapis.com)

```sh
############# Enable the APIs for Vertex AI Project ########################
gcloud services enable --project=$PROJECT_ID accesscontextmanager.googleapis.com
```

# 1-0. Create and Enforce VPC-SC Perimeter

## 1-1. Create Access Context Manager Policy
```sh
gcloud access-context-manager policies create \
  --organization $ORGANIZATION_ID --scopes=$SCOPE --title $POLICY_TITLE
```

Get the access policy number
```sh
gcloud access-context-manager policies list \
  --organization $ORGANIZATION_ID
```

```sh
export POLICY_NUMBER='341180207387' # This is the identifier for the access policy you created in the previous step.
export POLICY="accessPolicies/$POLICY_NUMBER"
```

Add IAM Binding to user
```sh
gcloud access-context-manager policies add-iam-policy-binding \
  $POLICY --member=user:$PRINCIPAL --role=$ROLE
```

## 1-2. Create Perimeter for in scope project

Public docs reference: [create-service-perimeters](https://cloud.google.com/vpc-service-controls/docs/create-service-perimeters#create-perimeter)

```sh
export PERIMETER_NAME='ai_ml_perimeter'
export TITLE='AI_ML_Perimeter'
export TYPE='regular'
export RESOURCES="projects/${PROJECT_NUMBER}"
export RESTRICTED_SERVICES='storage.googleapis.com,bigquery.googleapis.com,aiplatform.googleapis.com,compute.googleapis.com,dns.googleapis.com,artifactregistry.googleapis.com'
```

Create the Ingress Rule
```sh
cat > ingress.yaml <<EOF
# https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#ingress-rules-reference
- ingressFrom:
    # ANY_IDENTITY | ANY_USER_ACCOUNT | ANY_SERVICE_ACCOUNT
    # identityType: ANY_IDENTITY
    # *OR*
    identities:
    # - serviceAccount:service-$PROJECT_NUMBER@gcp-sa-aiplatform-cc.iam.gserviceaccount.com
    # - serviceAccount:service-$PROJECT_NUMBER@gcp-sa-aiplatform.iam.gserviceaccount.com
    # - serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com
    # - serviceAccount:$SERVICE_ACCOUNT_VERTEX
    - user:$PRINCIPAL
    sources:
    # - resource: projects/project
    # *OR*
    - accessLevel: "*"
  ingressTo:
    operations:
    - serviceName: storage.googleapis.com
      methodSelectors:
      - method: "*"
    - serviceName: aiplatform.googleapis.com
      methodSelectors:
      - method: "*"
    - serviceName: artifactregistry.googleapis.com
      methodSelectors:
      - method: "*"
    resources:
    - projects/$PROJECT_NUMBER
  title: "Ingress to Vertex AI, Artifact Registry and Cloud Storage"
EOF
```

Create the Egress Rule
```sh
cat > egress.yaml <<EOF
# https://cloud.google.com/vpc-service-controls/docs/ingress-egress-rules#egress-rules-reference
- egressTo:
    # operations:
    # - serviceName: "*"
      # methodSelectors:
      # - method: "*"
      # *OR*
      # - permission: permission
    # resources:
    # - projects/project
    # - "*"
    # *OR*
    # externalResources:
    # - external-resource-path
  egressFrom:
    # ANY_IDENTITY | ANY_USER_ACCOUNT | ANY_SERVICE_ACCOUNT
    # identityType: ANY_IDENTITY
    # *OR*
    # identities:
    # - serviceAccount:service-account
    # - user:user-account
  title: No Egress
EOF
```

```sh
gcloud access-context-manager perimeters dry-run create $PERIMETER_NAME \
  --perimeter-title=$TITLE \
  --perimeter-type=$TYPE \
  --perimeter-resources=$RESOURCES \
  --perimeter-restricted-services=$RESTRICTED_SERVICES \
  --perimeter-ingress-policies=ingress.yaml \
  --perimeter-egress-policies=egress.yaml \
  --policy=$POLICY_NUMBER
```

## 1-3. Enforce the Dry-Run Configuration

Public docs reference: [manage-dry-run-configurations#enforce-configuration](https://cloud.google.com/vpc-service-controls/docs/manage-dry-run-configurations#enforce-configuration)
```sh
gcloud access-context-manager perimeters dry-run enforce $PERIMETER_NAME \
  --policy=$POLICY_NUMBER
```

Public docs reference: [manage-dry-run-configurations#identifying_blocked_requests](https://cloud.google.com/vpc-service-controls/docs/manage-dry-run-configurations#identifying_blocked_requests)
```sh
gcloud logging read 'log_id("cloudaudit.googleapis.com/policy") AND severity="error" AND protoPayload.metadata.dryRun="true"'
```

## 1-4. [Optional] Update the Perimeter (if needed)
```sh
gcloud access-context-manager perimeters update $PERIMETER_NAME \
  --title=$TITLE \
  --type=$TYPE \
  --set-resources=$RESOURCES \
  --set-restricted-services=$RESTRICTED_SERVICES \
  --set-ingress-policies=ingress.yaml \
  --set-egress-policies=egress.yaml \
  --policy=$POLICY_NUMBER
```

# 2-0. Run Vertex AI Pipelines with VPC-SC

Now that you've created a VPC-SC Perimeter, you can run Vertex AI Pipelines with VPC-SC. Go back to the [Vertex AI Pipelines Introduction Sample](1_Vertex_AI_Pipelines_Introduction.ipynb) and re-run the pipelines to inspect logs and ensure your jobs are running as expected.

* [1_Vertex_AI_Pipelines_Introduction.ipynb](1_Vertex_AI_Pipelines_Introduction.ipynb)


# 3-0. Cleaning up

To clean up all Google Cloud resources used in this project, you can [delete the Google Cloud
project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#shutting_down_projects) you used for the tutorial.

Otherwise, you can delete the individual resources you created in this tutorial:

- VPC-SC Perimeter

# 4-0. Summary

This example shows you how to host a private PyPI repository on GCP Artifact Registry and configure VPC-SC to allow Vertex AI Pipelines to access the repository. For production best-practice, adding dependencies into the docker images of Vertex AI Pipelines is recommended, which provides more reliable and repeatable environment and reduces runtime cost.

Sometimes users do favor the flexibility of installing dependencies on the fly. In that case, users can host a private PyPI repository. 

An **alternative approach from this sample** is to provide network egress connectivity for Vertex AI Pipelines to your VPC via **VPC Peering** or **PSC-I** to reach a private PyPI repository:
- [Set up VPC Network Peering for certain Vertex AI resources](https://cloud.google.com/vertex-ai/docs/general/vpc-peering)
- [Configure Private Service Connect interface for a pipeline](https://cloud.google.com/vertex-ai/docs/pipelines/configure-private-service-connect)
