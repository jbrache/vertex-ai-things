export REGION="us-central1"
export PROJECT_ID="[your-project-id]"
export SA_NAME="function-calling-service"
export SA_DESCRIPTION="For demoing Gemini function calling: for the app to read data from BigQuery, run BigQuery jobs, and use resources in Vertex AI."
export SA_DISPLAY_NAME="Function calling service"

gcloud config set project $PROJECT_ID

gcloud iam service-accounts create $SA_NAME \
  --description="$SA_DESCRIPTION" \
  --display-name="$SA_DISPLAY_NAME"

gcloud projects add-iam-policy-binding {PROJECT_ID} \
  --member=f"serviceAccount:{SA_NAME}@{PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding {PROJECT_ID} \
  --member="serviceAccount:{SA_NAME}@{PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"

gcloud run deploy function-calling-service-flask \
    --allow-unauthenticated \
    --source="." \
    --region={REGION} \
    --port=8080 \
    --service-account="{SA_NAME}@{PROJECT_ID}.iam.gserviceaccount.com"