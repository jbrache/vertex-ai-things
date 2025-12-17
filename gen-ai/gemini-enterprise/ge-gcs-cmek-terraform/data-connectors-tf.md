# DataConnector Setup Terraform Example

## How to run/test terraform
1. Install [gcloud CLI(https://cloud.google.com/sdk/docs/install) and [terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)
2. Set the following parameters and authenticate with gcloud CLI tool

Configure this as overrides for the default quota-project.
```bash
export PROJECT_ID="ge-tf-testing-001"
export USER_PROJECT_OVERRIDE=true
export GOOGLE_PROJECT=$PROJECT_ID$
export GOOGLE_USE_DEFAULT_CREDENTIALS=true
gcloud auth application-default login
gcloud auth application-default set-quota-project $PROJECT_ID
```

3. Create a `main.tf` file with touch main.tf and add cloud resources. Example:
```bash
# Simple data store resource
resource "google_discovery_engine_data_store" "basic" {
  location                     = "global"
  data_store_id                = "data-store-id"
  display_name                 = "tf-test-structured-datastore"
  industry_vertical            = "GENERIC"
  content_config               = "NO_CONTENT"
  solution_types               = ["SOLUTION_TYPE_SEARCH"]
  create_advanced_site_search  = false
  skip_default_schema_creation = false
}
```

4. Runs `terraform init -upgrade` to get the latest provider
5. Runs `terraform plan` to preview the execution plan
6. Runs `terraform apply` to execute and create cloud resources
7. Runs `terraform destroy` to delete the cloud resources

Terraform documentation:
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/discovery_engine_data_connector 

REST API:
https://docs.cloud.google.com/generative-ai-app-builder/docs/reference/rest

## Creating and Linking DataConnector To Search Engine

```tf
# Create Onedrive data connector 1
resource "google_discovery_engine_data_connector" "basic1" {
  location                = "global"
  collection_id           = "connector-id-1"
  collection_display_name = "tf-test-dataconnector-outlook"
  data_source             = "onedrive"
  params                  = {
    auth_type             = "OAUTH_TWO_LEGGED"
    client_id             = "projects/*/locations/*/secrets/*/versions/*"
    client_secret         = "projects/*/locations/*/secrets/*/versions/*"
    instance_uri          = "https://vaissptbots-my.sharepoint.com/"
    tenant_id             = "projects/*/locations/*/secrets/*/versions/*"
  }
  
  refresh_interval        = "86400s"
  entities {
    entity_name           = "file"
  }
  static_ip_enabled       = false
}

# Create Onedrive data connector 2
resource "google_discovery_engine_data_connector" "basic2" {
  location                = "global"
  collection_id           = "connector-id-2"
  collection_display_name = "tf-test-dataconnector-outlook"
  data_source             = "onedrive"
  params                  = {
    auth_type             = "OAUTH_TWO_LEGGED"
    client_id             = "projects/*/locations/*/secrets/*/versions/*"
    client_secret         = "projects/*/locations/*/secrets/*/versions/*"
    instance_uri          = "https://vaissptbots-my.sharepoint.com/"
    tenant_id             = "projects/*/locations/*/secrets/*/versions/*"
  }
  
  refresh_interval        = "86400s"
  entities {
    entity_name           = "file"
  }
  static_ip_enabled       = false
}

# Create search app
resource "google_discovery_engine_search_engine" "basic" {
  engine_id = "tf-test-2"
  collection_id = "default_collection"
  location = google_discovery_engine_data_connector.basic1.location
  display_name = "TF test"

  # Connect data store ids to this engine. The data store ids from data connectors are
  # are formated as [collection_id]_[entity]. For example, the collection id of the 
  # connector above is connector-id-1, the resulting data_store_id would be 
  # connector-id-1_file for the file entity.
  data_store_ids = [
    format("%s_file", google_discovery_engine_data_connector.basic1.collection_id),
    format("%s_file", google_discovery_engine_data_connector.basic2.collection_id)
  ]
  industry_vertical           = "GENERIC"
  app_type                    = "APP_TYPE_INTRANET"
  search_engine_config {
  }
}
```

## DataConnector Terraform Examples

### Onedrive
```tf
resource "google_discovery_engine_data_connector" "basic" {
  location                = "global"
  collection_id           = "onedrive-connector-1"
  collection_display_name = "Onedrive Connector"
  data_source             = "onedrive"
  params                  = {
    auth_type             = "OAUTH_TWO_LEGGED"
    client_id             = "projects/*/locations/*/secrets/*/versions/*"
    client_secret         = "projects/*/locations/*/secrets/*/versions/*"
    instance_uri          = "https://vaissptbots-my.sharepoint.com/"
    tenant_id             = "projects/*/locations/*/secrets/*/versions/*"
  }
  refresh_interval        = "86400s"
  entities {
    entity_name           = "file"
  }
  static_ip_enabled       = false
}
```

### Outlook
```tf
resource "google_discovery_engine_data_connector" "basic" {
  location                = "global"
  collection_id           = "outlook-connector-1"
  collection_display_name = "Outlook Connector"
  data_source             = "outlook"
  params = {
    auth_type             = "OAUTH_TWO_LEGGED"
    instance_id           = "projects/*/locations/*/secrets/*/versions/*"
    client_secret         = "projects/*/locations/*/secrets/*/versions/*"    
    client_id             = "projects/*/locations/*/secrets/*/versions/*"
  }
  refresh_interval        = "86400s"
  entities {
    entity_name           = "mail"
  }
  entities {
    entity_name           = "mail-attachment"
  }
  entities {
    entity_name           = "calendar"
  }
  entities {
    entity_name           = "contact"
  }
}
```

### SharePoint
```tf
resource "google_discovery_engine_data_connector" "basic" {
  location                = "global"
  collection_id           = "sharepoint-connector-1"
  collection_display_name = "Sharepoint Connector"
  data_source             = "sharepoint"
  params                  = {
    auth_type             = "OAUTH_PASSWORD_GRANT"
    instance_uri          = ""
    tenant_id             = "projects/*/locations/*/secrets/*/versions/*"
    client_id             = "projects/*/locations/*/secrets/*/versions/*"
    client_secret         = "projects/*/locations/*/secrets/*/versions/*"
    user_account          = "projects/*/locations/*/secrets/*/versions/*"
    password              = "projects/*/locations/*/secrets/*/versions/*"
  }
  refresh_interval        = "86400s"
  entities {
    entity_name           = "attachment"
  }
  entities {
    entity_name           = "comment"
  }
  entities {
    entity_name           = "event"
  }
  entities {
    entity_name           = "page"
  }
  entities {
    entity_name           = "file"
  }
  entities {
    entity_name           = "site"
  }
  static_ip_enabled       = false
}
```

### Jira
```tf
resource "google_discovery_engine_data_connector" "basic" {
  location                = "global"
  collection_id           = "jira-connector-1"
  collection_display_name = "Jira Connector"
  data_source             = "jira"
  params = {
    auth_type             = "OAUTH"
    instance_uri          = "https://vaissptbots-my.sharepoint.com/"
    instance_id           = "projects/*/locations/*/secrets/*/versions/*"
    client_id             = "projects/*/locations/*/secrets/*/versions/*"
    client_secret         = "projects/*/locations/*/secrets/*/versions/*"
    refresh_token         = "projects/*/locations/*/secrets/*/versions/*"
  }
  refresh_interval        = "86400s"
  entities {
    entity_name           = "project"
  }
  entities {
    entity_name           = "issue"
  }
  entities {
    entity_name           = "attachment"
  }
  entities {
    entity_name           = "comment"
  }
  entities {
    entity_name           = "worklog"
  }
  static_ip_enabled       = false
}
```

### Confluence
```tf
resource "google_discovery_engine_data_connector" "basic" {
  location                = "global"
  collection_id           = "confluence-connector-1"
  collection_display_name = "Confluence Connector"
  data_source             = "confluence"
  params = {
    auth_type             = "OAUTH"
    instance_uri          = "https://vaissptbots-my.sharepoint.com/"
    instance_id           = "projects/*/locations/*/secrets/*/versions/*"
    client_id             = "projects/*/locations/*/secrets/*/versions/*"
    client_secret         = "projects/*/locations/*/secrets/*/versions/*"
    refresh_token         = "projects/*/locations/*/secrets/*/versions/*"
  }
  refresh_interval        = "86400s"
  entities {
    entity_name           = "page"
  }
  entities {
    entity_name           = "whiteboard"
  }
  entities {
    entity_name           = "blog"
  }
  entities {
    entity_name           = "comment"
  }
  entities {
    entity_name           = "attachment"
  }
  static_ip_enabled       = false
}
```

### ServiceNow
```tf
resource "google_discovery_engine_data_connector" "basic" {
  location                = "global"
  collection_id           = "servicenow-connector-1"
  collection_display_name = "ServiceNow Connector"
  data_source             = "servicenow"
  params                  = {
    auth_type             = "OAUTH_PASSWORD_GRANT"
    client_id             = "projects/*/locations/*/secrets/*/versions/*"
    client_secret         = "projects/*/locations/*/secrets/*/versions/*"
    instance_uri          = ""
    user_account          = ""
    password              = "projects/*/locations/*/secrets/*/versions/*"
  }
  refresh_interval        = "86400s"
  entities {
    entity_name           = "catalog"
  }
  entities {
    entity_name           = "incident"
  }
  entities {
    entity_name           = "knowledge_base"
  }
  static_ip_enabled       = false
}
```

### Slack
```tf
resource "google_discovery_engine_data_connector" "basic" {
  location                = "global"
  collection_id           = "slack-connector-1"
  collection_display_name = "Slack Connector"
  data_source             = "slack"
  params                  = {
    auth_type             = "API_TOKEN"
    instance_id           = "your_workspace_id_here"
    auth_token            = "projects/*/locations/*/secrets/*/versions/*"
  }
  refresh_interval        = "86400s"
  entities {
    entity_name           = "conversation"
  }
  entities {
    entity_name           = "message"
  }
  entities {
    entity_name           = "file"
  }
  static_ip_enabled       = false
  connector_modes         = ["DATA_INGESTION"]
}
```

### Gmail
```tf
resource "google_discovery_engine_data_connector" "basic" {
  location                     = "global"
  collection_id                = "gmail-connector-1"
  collection_display_name      = "gmail-connector-1"
  data_source                  = "google_mail"
  params                       = {}
  entities {
    entity_name                = "google_mail"
  }
  connector_modes              = ["FEDERATED"]
  refresh_interval             = "0s"
}
```

### Gdrive
```tf
resource "google_discovery_engine_data_connector" "basic" {
  location                     = "global"
  collection_id                = "gdrive-connector-1"
  collection_display_name      = "gdrive-connector-1"
  data_source                  = "google_drive"
  params                       = {}
  entities {
    entity_name                = "google_drive"
  }
  connector_modes              = ["FEDERATED"]
  refresh_interval             = "0s"
}
```