# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = { tenant_id = "00000000-0000-0000-0000-000000000001" }
  }
  mock_resource "azurerm_resource_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg" }
  }
  mock_resource "azurerm_service_plan" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/serverFarms/asp" }
  }
  mock_resource "azurerm_linux_web_app" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/sites/app" }
  }
  mock_resource "azurerm_application_insights" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Insights/components/appi" }
  }
  mock_resource "azurerm_private_dns_zone" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/privateDnsZones/zone" }
  }
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/psql" }
  }
}

mock_provider "random" {}

variables {
  project                        = "example"
  environment                    = "dev"
  subscription_id                = "00000000-0000-0000-0000-000000000000"
  location                       = "eastus2"
  owner                          = "platform-team"
  vnet_id                        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet"
  app_subnet_id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/app"
  db_subnet_id                   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/db"
  log_analytics_workspace_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log"
  container_registry_url         = "https://exampleregistry.azurecr.io"
  container_image                = "web:1.0.0"
  postgres_admin_group_object_id = "00000000-0000-0000-0000-000000000003"
  postgres_admin_group_name      = "example-db-admins"
}

run "no_passwords_anywhere" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server.db.authentication[0].password_auth_enabled == false
    error_message = "Database must accept Entra ID auth only."
  }
  assert {
    condition     = azurerm_postgresql_flexible_server.db.public_network_access_enabled == false
    error_message = "Database must not be publicly reachable."
  }
  assert {
    condition     = !azurerm_linux_web_app.app.ftp_publish_basic_authentication_enabled && !azurerm_linux_web_app.app.webdeploy_publish_basic_authentication_enabled
    error_message = "Basic-auth publishing must be off."
  }
  assert {
    condition     = length(azurerm_role_assignment.acr_pull) == 0 && length(azurerm_postgresql_flexible_server.db.high_availability) == 0
    error_message = "ACR pull and HA are opt-in."
  }
}

run "acr_and_ha_opt_in" {
  command = plan
  variables {
    acr_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ContainerRegistry/registries/acr"
    postgres_high_availability = true
  }

  assert {
    condition     = length(azurerm_role_assignment.acr_pull) == 1 && azurerm_linux_web_app.app.site_config[0].container_registry_use_managed_identity
    error_message = "Setting acr_id should grant AcrPull and pull with the managed identity."
  }
  assert {
    condition     = azurerm_postgresql_flexible_server.db.high_availability[0].mode == "ZoneRedundant"
    error_message = "HA should be zone redundant."
  }
}
