# Serverless API: Azure Functions on the Flex Consumption plan (Python) ->
# Cosmos DB for NoSQL (serverless). Everything authenticates with the
# function's managed identity: shared keys are off on the storage account
# and local (key) auth is off on Cosmos DB and Application Insights.
#
# Terraform creates the infrastructure only. Deploy the code in src/ with
#   func azure functionapp publish <function_app_name>
# or from CI, after apply.

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  name = "${var.project}-${var.environment}-${var.api_name}"

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Stack       = "functions-api"
  })

  # Built-in "Cosmos DB Built-in Data Contributor" role.
  cosmos_data_contributor = "00000000-0000-0000-0000-000000000002"
}

resource "azurerm_resource_group" "api" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "api" {
  name                = "log-${local.name}"
  resource_group_name = azurerm_resource_group.api.name
  location            = azurerm_resource_group.api.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

resource "azurerm_application_insights" "api" {
  name                         = "appi-${local.name}"
  resource_group_name          = azurerm_resource_group.api.name
  location                     = azurerm_resource_group.api.location
  workspace_id                 = azurerm_log_analytics_workspace.api.id
  application_type             = "web"
  local_authentication_enabled = false
  tags                         = local.tags
}

# --- Storage for the function host and deployment packages -------------------

# tflint-ignore: azurerm_resources_missing_prevent_destroy # host storage and deployment packages only; recreated on deploy
resource "azurerm_storage_account" "func" {
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed keys with infrastructure encryption; add a customer-managed key if your program requires one.
  #checkov:skip=CKV2_AZURE_33:The Functions host reaches storage over the public endpoint; add VNet integration and private endpoints if required.
  #checkov:skip=CKV_AZURE_59:See CKV2_AZURE_33.
  #checkov:skip=CKV_AZURE_33:Queue logging; host storage only.
  #checkov:skip=CKV_AZURE_206:Host storage holds no business data; LRS is sufficient.
  name                     = "st${var.project}${var.environment}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.api.name
  location                 = azurerm_resource_group.api.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags
}

# tflint-ignore: azurerm_resources_missing_prevent_destroy # deployment packages only
resource "azurerm_storage_container" "deployments" {
  #checkov:skip=CKV2_AZURE_21:Deployment packages only; blob read logging isn't needed.
  name                  = "deployments"
  storage_account_id    = azurerm_storage_account.func.id
  container_access_type = "private"
}

# --- Function app ------------------------------------------------------------

resource "azurerm_service_plan" "api" {
  #checkov:skip=CKV_AZURE_212:Flex Consumption (FC1) scales per request; worker count doesn't apply.
  #checkov:skip=CKV_AZURE_225:Flex Consumption (FC1) doesn't use plan-level zone balancing.
  name                = "asp-${local.name}"
  resource_group_name = azurerm_resource_group.api.name
  location            = azurerm_resource_group.api.location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azurerm_function_app_flex_consumption" "api" {
  name                = "func-${local.name}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.api.name
  location            = azurerm_resource_group.api.location
  service_plan_id     = azurerm_service_plan.api.id

  runtime_name    = "python"
  runtime_version = var.python_version

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.func.primary_blob_endpoint}${azurerm_storage_container.deployments.name}"
  storage_authentication_type = "SystemAssignedIdentity"

  maximum_instance_count = var.maximum_instance_count
  instance_memory_in_mb  = var.instance_memory_in_mb

  https_only                                     = true
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  dynamic "auth_settings_v2" {
    for_each = var.entra_client_id == null ? [] : [var.entra_client_id]
    content {
      auth_enabled           = true
      require_authentication = true
      require_https          = true
      unauthenticated_action = "Return401"
      default_provider       = "azureactivedirectory"

      active_directory_v2 {
        client_id            = auth_settings_v2.value
        tenant_auth_endpoint = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
        allowed_audiences    = ["api://${auth_settings_v2.value}", auth_settings_v2.value]
      }

      login {
        token_store_enabled = false
      }
    }
  }

  site_config {
    minimum_tls_version                    = "1.2"
    scm_minimum_tls_version                = "1.2"
    http2_enabled                          = true
    application_insights_connection_string = azurerm_application_insights.api.connection_string
  }

  app_settings = {
    AzureWebJobsStorage__accountName          = azurerm_storage_account.func.name
    APPLICATIONINSIGHTS_AUTHENTICATION_STRING = "Authorization=AAD"
    COSMOS_ENDPOINT                           = azurerm_cosmosdb_account.api.endpoint
    COSMOS_DATABASE                           = azurerm_cosmosdb_sql_database.api.name
    COSMOS_CONTAINER                          = azurerm_cosmosdb_sql_container.items.name
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "func_storage" {
  for_each = toset([
    "Storage Blob Data Owner",
    "Storage Queue Data Contributor",
    "Storage Table Data Contributor",
  ])

  scope                = azurerm_storage_account.func.id
  role_definition_name = each.value
  principal_id         = azurerm_function_app_flex_consumption.api.identity[0].principal_id
}

resource "azurerm_role_assignment" "func_app_insights" {
  scope                = azurerm_application_insights.api.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_function_app_flex_consumption.api.identity[0].principal_id
}

# --- Cosmos DB ---------------------------------------------------------------

resource "azurerm_cosmosdb_account" "api" {
  #checkov:skip=CKV_AZURE_140:Disabled with local_authentication_enabled = false (azurerm 5.x); checkov reads the 4.x attribute name.
  #checkov:skip=CKV_AZURE_99:Serverless account without VNet integration; restrict with ip_range_filter or private endpoints if required.
  #checkov:skip=CKV_AZURE_101:See CKV_AZURE_99.
  #checkov:skip=CKV_AZURE_100:Microsoft-managed keys; add key_vault_key_id if your program requires customer-managed keys.
  name                               = "cosmos-${local.name}-${random_string.suffix.result}"
  resource_group_name                = azurerm_resource_group.api.name
  location                           = azurerm_resource_group.api.location
  offer_type                         = "Standard"
  kind                               = "GlobalDocumentDB"
  local_authentication_enabled       = false
  access_key_metadata_writes_enabled = false
  minimal_tls_version                = "Tls12"
  public_network_access_enabled      = true

  capabilities {
    name = "EnableServerless"
  }

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.api.location
    failover_priority = 0
  }

  backup {
    type = "Continuous"
    tier = "Continuous7Days"
  }

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_cosmosdb_sql_database" "api" {
  name                = var.api_name
  resource_group_name = azurerm_resource_group.api.name
  account_name        = azurerm_cosmosdb_account.api.name

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_cosmosdb_sql_container" "items" {
  name                = "items"
  resource_group_name = azurerm_resource_group.api.name
  account_name        = azurerm_cosmosdb_account.api.name
  database_name       = azurerm_cosmosdb_sql_database.api.name
  partition_key_paths = ["/id"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_cosmosdb_sql_role_assignment" "func" {
  resource_group_name = azurerm_resource_group.api.name
  account_name        = azurerm_cosmosdb_account.api.name
  role_definition_id  = "${azurerm_cosmosdb_account.api.id}/sqlRoleDefinitions/${local.cosmos_data_contributor}"
  principal_id        = azurerm_function_app_flex_consumption.api.identity[0].principal_id
  scope               = "${azurerm_cosmosdb_account.api.id}/dbs/${azurerm_cosmosdb_sql_database.api.name}"
}
