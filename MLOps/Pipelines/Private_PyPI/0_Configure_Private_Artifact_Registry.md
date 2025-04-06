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

# Vertex AI Pipelines: Configure Private Artifact Registry Python Repository and setup KFP Base Image

| Author(s) |
| --- |
| [Jose Brache](https://github.com/jbrache) |

## Overview

When using [Vertex AI Pipelines](https://cloud.google.com/vertex-ai/docs/pipelines/introduction) you may want to authenticate with a Python Package Index (PyPI) repository hosted on Artifact Registry.

This guide shows how to set up configure a private [Artifact Registry Python repository](https://cloud.google.com/artifact-registry/docs/python/store-python) and authenticate to it with Vertex AI Pipelines to install Python packages. Kubeflow exposes `pip_index_urls` providing the ability to pip install `packages_to_install` from package indices other than the default [PyPI.org](PyPI.org). 

Review the public docs for the latest information on support:
- [Artifact Registry Python repository](https://cloud.google.com/artifact-registry/docs/python/store-python)
- [Configure authentication to Artifact Registry for Python package repositories](https://cloud.google.com/artifact-registry/docs/python/authentication)

This example covers the following steps:
1. Create a private Artifact Registry Python repository
2. Obtain Python Packages
3. Upload the package to the repository
4. Create KFP Base Image, configured to authenticate to Artifact Registry
5. Build and Push Custom Container to Artifact Registry
6. Summary and Next steps: Run through the [Vertex AI Pipelines Introduction](1_Vertex_AI_Pipelines_Introduction.ipynb) notebook to use the private Artifact Registry Python repository and base container image with Vertex AI Pipelines.

# 0-0. Set Google Cloud project information

To get started using Vertex AI, you must have an existing Google Cloud project and [enable the Vertex AI API](https://console.cloud.google.com/flows/enableapi?apiid=aiplatform.googleapis.com).

Learn more about [setting up a project and a development environment](https://cloud.google.com/vertex-ai/docs/start/cloud-environment).

```sh
export PROJECT_ID="ds-dev-jb02-psci"
# For the Artifact Registry Python repository
export REPOSITORY="python-repo-vertex"
export LOCATION="us-central1"
export DESCRIPTION="Python package repository"

# For the Artifact Registry container image repository
export REGION='us-central1'
export PRIVATE_REPO="kfp-base-images"
```

```sh
gcloud config set project $PROJECT_ID
```

# 1-0. Create a repository
This sectino shows you how to set up a private Artifact Registry Python repository, upload a package, and then install the package. See the public docs: [Store Python packages](https://cloud.google.com/artifact-registry/docs/python/store-python) for more information on these steps. You can also complete these steps in a Cloud Shell from the Google Cloud Console.

## 1-1. Create the repository for your packages.
Run the following command to create a new Python package repository in the current project named `python-repo-vertex` in the location `us-central1`.

```sh
gcloud artifacts repositories create $REPOSITORY \
    --project=$PROJECT_ID \
    --repository-format=python \
    --location=$LOCATION \
    --description="Python package repository"
```

Run the following command to verify that your repository was created:

```sh
gcloud artifacts repositories list
```

To simplify gcloud commands, set the default repository to `python-repo-vertex` and the default location to `us-central1`. After the values are set, you do not need to specify them in `gcloud` commands that require a repository or a location.

To set the repository and location, run the commands:
```sh
gcloud config set artifacts/repository $REPOSITORY
gcloud config set artifacts/location $LOCATION
```

## 1-2. Configure authentication

The Artifact Registry keyring backend finds your credentials using Application Default Credentials (ADC), a strategy that looks for credentials in your environment.

To generate credentials for ADC, run the following command:
```sh
gcloud auth application-default login
```

For details on authentication methods and adding repositories to pip and Twine configuration, see [Setting up authentication to Python package repositories](https://cloud.google.com/artifact-registry/docs/python/authentication).

# 2-0. Configure Python interpreter
Since the Vertex AI Pipelines job in future steps uses an image with Python 3.11, these steps configure a Python 3.11 with [pyenv](https://github.com/pyenv/pyenv) to download source distributions.

## 2-1. Installing Pyenv

Public docs reference which contain other options: [Getting Pyenv](https://github.com/pyenv/pyenv). This just uses the automatic installer for Linux:
```sh
curl -fsSL https://pyenv.run | bash
```

## 2-2. Set up your shell environment for Pyenv
Public docs reference which contain other options: [Set up your shell environment for Pyenv](https://github.com/pyenv/pyenv). This option is for `Bash`:
```sh
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
```

## 2-3. Install and Set Python Version
Since `Python 3.11` is used in our base container image in future steps, these steps install `Python 3.11` and set it as the default version:

Intall Python 3.11
```sh
pyenv install 3.11
```

Set Python 3.11 as the default version
```sh
pyenv global 3.11
```

## 2-4. Install required packages
[Twine](https://pypi.org/project/twine/) is a tool for
publishing Python packages. You'll use Twine to upload a package to
Artifact Regsitry.

In this guide you use the Python installation configured with `Pyenv`. You will also need to install the [Artifact Registry keyring backend](https://pypi.org/project/keyrings.google-artifactregistry-auth):
to handle authentication with Artifact Registry. If you create
a [virtual environment](https://docs.python.org/3/tutorial/venv.html) or set up Python outside of `Pyenv` you must install the keyring backend for authentication.
For details, see [Authenticating with keyring](https://cloud.google.com/artifact-registry/docs/python/authentication#keyring).

To install Twine, run the command:

```sh
pip install twine --upgrade
```

To install the keyring backend, run the commands:
```sh
pip install keyring --upgrade
pip install keyrings.google-artifactregistry-auth --upgrade
```

You are now ready to set up Artifact Registry.

# 3-0. Obtain Python Packages
When you build a Python project, distribution files are saved in a `dist` subdirectory in your Python project. To simplify this quickstart, you will download prebuilt package files.

## 3-1. Create a Python project folder

The `REPOSITORY` environment variable defined above is configured as `python-repo-vertex`. This also adds a `dist` subdirectory for they Python packages.
```sh
mkdir $REPOSITORY
mkdir $REPOSITORY/dist
```

Change to the `dist` directory.
```sh
cd $REPOSITORY/dist
```

## 3-2. Download the Python packages

This example downloads the `google-genai` Python package.

The command `pip install --no-binary=:none: <package_name>` instructs `pip` to install the specified package from source, regardless of whether a pre-built binary wheel is available. The option `--no-binary=:none:` specifically tells pip not to use any binary packages for the given install, forcing it to download the source package (sdist) and build it locally.

```sh
pip download \
    --index-url https://pypi.org/simple/ \
    --no-binary=:none: \
    google-genai
```

The command downloads the `google-genai` package and its dependencies.

# 4-0. Upload the package to the repository

Use Twine to upload your packages to your repository.

From the `dist` directory, change to the parent directory.
```sh
cd ..
```

Upload the packages to the repository from your dist directory.

```sh
python3 -m twine upload --repository-url https://us-central1-python.pkg.dev/$PROJECT_ID/$REPOSITORY/ dist/*
```

When you run the command with `python3 -m`, Python locates twine and runs the command. If the twine command is in your system path, you can run it without `python3 -m`.

Twine uploads the `google-genai` package and its dependencies to your repository.

## 4-1. [Optional] View the package in the repository
To verify that your package was added, list the packages in the `python-repo-vertex` repository.

Run the following command:
```sh
gcloud artifacts packages list --repository=$REPOSITORY
```

To view versions for a package, run the following command:
```sh
export PACKAGE="google-genai"
gcloud artifacts versions list --package=$PACKAGE
```
Where `PACKAGE` is the package ID.

## 4-2. [Optional] Install the package
Run the following command to install the package:
```sh
export PACKAGE="google-genai"
pip install --index-url https://us-central1-python.pkg.dev/$PROJECT_ID/$REPOSITORY/simple/ $PACKAGE
```

**Troubleshooting**: By default, tools such as `pip` and Twine do not return detailed error messages. If you encounter an error, rerun the command with the `--verbose` flag to get more detailed output. See [Troubleshooting for Python packages](https://cloud.google.com/artifact-registry/docs/troubleshooting#pypi) for more information.

# 5-0. Create KFP Base Image

```sh
# Training code container def
export CONTAINER_DIR="kfp_container"
```

Create the location where the container Dockerfile will be stored
```sh
# Remove if there's any such folder already
rm -rf $CONTAINER_DIR
# Create your app directory
mkdir -p $CONTAINER_DIR
```

Create the Dockerfile
```sh
cat > $CONTAINER_DIR/Dockerfile <<EOF
FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir kfp==2.12.1 pandas google-cloud-aiplatform
# Used for authenticating to Artifact Registry
RUN pip install --no-cache-dir keyring keyrings.google-artifactregistry-auth

COPY . /app

CMD ["echo", "Kubeflow base image built successfully"]
EOF
```

## 5-1. Build and Push Custom Container to Artifact Registry

You must have enabled the Artifact Registry API for your project in the previous steps. You will store your custom training container in Artifact Registry.

### 5-1-1. Create a private Docker repository
Your first step is to create a Docker repository in Artifact Registry.

1 - Run the `gcloud artifacts repositories create` command to create a new Docker repository with your region with the description `Docker repository`.

2 - Run the `gcloud artifacts repositories list` command to verify that your repository was created.

```sh
# Repo to create / use for running training job

export BASE_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${PRIVATE_REPO}/python-3.11-slim:latest"

echo "Private Repo:", $PRIVATE_REPO
echo "Training Container Image:", $BASE_IMAGE
```

```sh
gcloud artifacts repositories create ${PRIVATE_REPO} --repository-format=docker --project=${PROJECT_ID} --location=${REGION} --description="Docker repository"
```

```sh
gcloud artifacts repositories --project=${PROJECT_ID} list
```

### 5-1-2. Build and push the custom docker container image by using Cloud Build
Build and push a Docker image with Cloud Build
```sh
cd $CONTAINER_DIR && gcloud builds submit --timeout=1800s --project=${PROJECT_ID} --region=${REGION} --tag ${BASE_IMAGE}
```

# 6-0. Summary

In this guide you learned how to
- Create a private Artifact Registry Python repository
- Obtain Python Packages
- Upload the package to the repository
- Create KFP Base Image, configured to authenticate to Artifact Registry
- Build and Push Custom Container to Artifact Registry

The next step is to use the configured repositories in Vertex AI Pipelines: [Vertex AI Pipelines Introduction](1_Vertex_AI_Pipelines_Introduction.ipynb).
