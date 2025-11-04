#!/usr/bin/env bash

export PROJECT_ID="[your-project-id]"
export GOOGLE_MAPS_API_KEY="[your-maps-api-key]"
export CLOUD_RUN_NAME="gemini-function-calling"
export SA_NAME="gemini-function-calling-app"
export SA_DESCRIPTION="For demoing Gemini function calling: for the app to read data from BigQuery, run BigQuery jobs, and use resources in Vertex AI."
export SA_DISPLAY_NAME="gemini-function-calling-app"

# https://cloud.google.com/iam/docs/service-accounts-create#gcloud
gcloud iam service-accounts create $SA_NAME \
  --description="$SA_DESCRIPTION" \
  --display-name="$SA_DISPLAY_NAME"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

gcloud run deploy $CLOUD_RUN_NAME \
  --allow-unauthenticated \
  --region us-central1 \
  --service-account $SA_NAME@$PROJECT_ID.iam.gserviceaccount.com \
  --source . \
  --update-env-vars GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY

  gcloud run services add-iam-policy-binding $CLOUD_RUN_NAME \
    --member="allUsers" \
    --role="roles/run.invoker"