#!/usr/bin/env bash

# Enable Vertex AI and BigQuery
gcloud services enable aiplatform.googleapis.com
gcloud services enable bigquery.googleapis.com

# Install Python
# https://docs.streamlit.io/get-started/installation/command-line
python3 -m venv .venv
source .venv/bin/activate
pip install streamlit
pip install google-cloud-aiplatform
pip install google-cloud-bigquery

# Install packages
${PYTHON_PREFIX}/bin/pip install -r requirements.txt

# Run app
${PYTHON_PREFIX}/bin/streamlit run Intro.py --server.enableCORS=false --server.enableXsrfProtection=false --server.port 8080
