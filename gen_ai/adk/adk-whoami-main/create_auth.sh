export PROJECT_NUMBER="123456789"
export AUTH_ID="whoami_auth"
export OAUTH_CLIENT_ID="<oauth_client_id>"
export OAUTH_CLIENT_SECRET="<oauth_client_secret>"
export OAUTH_AUTH_URI="<oauth_auth_uri>"

export OAUTH_TOKEN_URI="https://oauth2.googleapis.com/token"

curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -H "X-Goog-User-Project: ${PROJECT_NUMBER}" \
https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUMBER}/locations/global/authorizations?authorizationId=${AUTH_ID} \
  -d '{
  "name": "projects/'"${PROJECT_NUMBER}"'/locations/global/authorizations/'"${AUTH_ID}"'",
  "serverSideOauth2": {
      "clientId": "'"${OAUTH_CLIENT_ID}"'",
      "clientSecret": "'"${OAUTH_CLIENT_SECRET}"'",
      "authorizationUri": "'"${OAUTH_AUTH_URI}"'",
      "tokenUri": "'"${OAUTH_TOKEN_URI}"'"
    }
  }'