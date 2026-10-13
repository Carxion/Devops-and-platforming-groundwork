# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = { tenant_id = "00000000-0000-0000-0000-000000000001" }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log" }
  }
  mock_resource "azurerm_application_insights" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Insights/components/appi" }
  }
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/st"
      primary_blob_endpoint = "https://st.blob.core.windows.net/"
    }
  }
  mock_resource "azurerm_service_plan" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/serverFarms/asp" }
  }
  mock_resource "azurerm_function_app_flex_consumption" {
    defaults = { identity = [{ type = "SystemAssigned", principal_id = "00000000-0000-0000-0000-000000000006", tenant_id = "00000000-0000-0000-0000-000000000001", identity_ids = [] }] }
  }
  mock_resource "azurerm_cosmosdb_account" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.DocumentDB/databaseAccounts/cosmos"
      endpoint = "https://cosmos.documents.azure.com:443/"
    }
  }
}

mock_provider "random" {}

variables {
  project         = "example"
  environment     = "dev"
  subscription_id = "00000000-0000-0000-0000-000000000000"
  location        = "eastus2"
  owner           = "platform-team"
}

run "keyless_by_default" {
  command = plan

  assert {
    condition     = azurerm_storage_account.func.shared_access_key_enabled == false
    error_message = "Host storage must not allow shared keys."
  }
  assert {
    condition     = azurerm_cosmosdb_account.api.local_authentication_enabled == false
    error_message = "Cosmos DB must not allow key auth."
  }
  assert {
    condition     = azurerm_function_app_flex_consumption.api.storage_authentication_type == "SystemAssignedIdentity"
    error_message = "Deployment storage should use the managed identity."
  }
  assert {
    condition     = length(azurerm_function_app_flex_consumption.api.auth_settings_v2) == 0
    error_message = "Platform auth is opt-in via entra_client_id."
  }
}

run "entra_auth_rejects_anonymous" {
  command = plan
  variables {
    entra_client_id = "00000000-0000-0000-0000-000000000007"
  }

  assert {
    condition     = azurerm_function_app_flex_consumption.api.auth_settings_v2[0].unauthenticated_action == "Return401"
    error_message = "Unauthenticated calls should get 401."
  }
}

run "rejects_long_environment" {
  command = plan
  variables {
    environment = "production-east"
  }
  expect_failures = [var.environment]
}
