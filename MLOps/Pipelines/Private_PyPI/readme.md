# Overview

When using [Vertex AI Pipelines](https://cloud.google.com/vertex-ai/docs/pipelines/introduction) you may want to authenticate with a Python Package Index (PyPI) repository hosted on Artifact Registry.

This guide shows how to set up configure a private [Artifact Registry Python repository](https://cloud.google.com/artifact-registry/docs/python/store-python) and authenticate to it with Vertex AI Pipelines to install Python packages. [Kubeflow exposes](https://www.kubeflow.org/docs/components/pipelines/user-guides/components/lightweight-python-components/#pip_index_urls) `pip_index_urls` providing the ability to pip install `packages_to_install` from package indices other than the default [PyPI.org](PyPI.org). 

## Get Started
1. Setup the pre-requisites with: [0_Configure_Private_Artifact_Registry.md](0_Configure_Private_Artifact_Registry.md)
2. Once you've configured your private Artifact Registry Python repository and custom container base image move to: [1_Vertex_AI_Pipelines_Introduction.ipynb](1_Vertex_AI_Pipelines_Introduction.ipynb)
