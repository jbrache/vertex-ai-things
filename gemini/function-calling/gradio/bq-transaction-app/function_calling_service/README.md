# Function Calling Service

This project demonstrates how to use the [Function Calling](https://cloud.google.com/vertex-ai/generative-ai/docs/multimodal/function-calling) service in a [Cloud Run](https://cloud.google.com/run) service.

It leverages the Python BigQuery client as a Cloud Run service.

## Prerequisites

* Set your Google Cloud Project through an environment variable `GOOGLE_CLOUD_PROJECT`.

## Test

* Install the dependencies with `pip install -r requirements.txt`
* Run `python app/main.py` to locally run the development server to run this Flask application.

## Deployment

Use `gcloud run deploy` to deploy the application to a Cloud Run service. Inspect the `setup-steps.sh` file for more detailed steps.

## Acknowledgements

If you're looking for a barebones example, review [this](https://github.com/GoogleCloudPlatform/generative-ai/tree/main/gemini/function-calling/function_calling_service) sample.