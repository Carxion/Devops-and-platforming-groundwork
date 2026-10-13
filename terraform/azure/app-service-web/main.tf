# Containerized web app on App Service (Linux, zone-balanced Premium v3)
# with outbound VNet integration, and a private PostgreSQL Flexible Server
# that accepts only Entra ID authentication. The app has a system-assigned
# managed identity; there are no passwords or connection strings with
# secrets in app settings.
#
# After apply, a database admin (member of postgres_admin_group) creates a
# least-privilege role for the app's identity:
#   SELECT * FROM pgaadauth_create_principal('<web_app_name>', false, false);

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  name         = "${var.project}-${var.environment}-${var.app_name}"
  web_app_name = "app-${local.name}-${random_string.suffix.result}"

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Stack       = "app-service-web"
  })
}

resource "azurerm_resource_group" "app" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_application_insights" "app" {
  name                         = "appi-${local.name}"
  resource_group_name          = azurerm_resource_group.app.name
  location                     = azurerm_resource_group.app.location
  workspace_id                 = var.log_analytics_workspace_id
  application_type             = "web"
  local_authentication_enabled = false
  tags                         = local.tags
}

# --- App Service -------------------------------------------------------------

resource "azurerm_service_plan" "app" {
  name                   = "asp-${local.name}"
  resource_group_name    = azurerm_resource_group.app.name
  location               = azurerm_resource_group.app.location
  os_type                = "Linux"
  sku_name               = var.app_service_sku
  worker_count           = var.worker_count
  zone_balancing_enabled = var.zone_balancing
  tags                   = local.tags
}

resource "azurerm_linux_web_app" "app" {
  #checkov:skip=CKV_AZURE_13:Authentication is app-specific (Entra ID, an IdP, or in-app); add auth_settings_v2 if the platform should enforce it.
  #checkov:skip=CKV_AZURE_17:Client certificates depend on the app's auth model; most apps use Entra ID or app-level auth instead.
  #checkov:skip=CKV_AZURE_88:Containerized app with no Azure Files mount.
  #checkov:skip=CKV_AZURE_222:Internet-facing web app; front it with Front Door or Application Gateway and restrict here if required.
  name                = local.web_app_name
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
  service_plan_id     = azurerm_service_plan.app.id

  https_only                                     = true
  client_affinity_enabled                        = false
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  virtual_network_subnet_id                      = var.app_subnet_id
  vnet_image_pull_enabled                        = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                               = true
    ftps_state                              = "Disabled"
    http2_enabled                           = true
    minimum_tls_version                     = "1.2"
    scm_minimum_tls_version                 = "1.2"
    health_check_path                       = var.health_check_path
    health_check_eviction_time_in_min       = 5
    vnet_route_all_enabled                  = true
    container_registry_use_managed_identity = var.acr_id != null

    application_stack {
      docker_image_name   = var.container_image
      docker_registry_url = var.container_registry_url
    }
  }

  app_settings = merge(var.app_settings, {
    APPLICATIONINSIGHTS_CONNECTION_STRING     = azurerm_application_insights.app.connection_string
    APPLICATIONINSIGHTS_AUTHENTICATION_STRING = "Authorization=AAD"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE       = "false"
    PGHOST                                    = azurerm_postgresql_flexible_server.db.fqdn
    PGDATABASE                                = azurerm_postgresql_flexible_server_database.app.name
    PGUSER                                    = local.web_app_name # the managed identity's database role
    PGSSLMODE                                 = "require"
  })

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  count = var.acr_id == null ? 0 : 1

  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

resource "azurerm_role_assignment" "app_insights" {
  scope                = azurerm_application_insights.app.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

resource "azurerm_monitor_diagnostic_setting" "app" {
  name                       = "to-log-analytics"
  target_resource_id         = azurerm_linux_web_app.app.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}

# --- Database ----------------------------------------------------------------

resource "azurerm_private_dns_zone" "db" {
  name                = "${local.name}.private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.app.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "db" {
  name                = "link-${local.name}"
  private_dns_zone_id = azurerm_private_dns_zone.db.id
  virtual_network_id  = var.vnet_id
  tags                = local.tags
}

resource "azurerm_postgresql_flexible_server" "db" {
  #checkov:skip=CKV_AZURE_136:Geo-redundant backup is a per-program DR decision and isn't available in every region.
  #checkov:skip=CKV2_AZURE_57:Network access is through VNet integration (delegated subnet), not a private endpoint.
  name                          = "psql-${local.name}-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.app.name
  location                      = azurerm_resource_group.app.location
  version                       = var.postgres_version
  sku_name                      = var.postgres_sku
  storage_mb                    = var.postgres_storage_mb
  auto_grow_enabled             = true
  backup_retention_days         = var.backup_retention_days
  delegated_subnet_id           = var.db_subnet_id
  private_dns_zone_id           = azurerm_private_dns_zone.db.id
  public_network_access_enabled = false
  zone                          = "1"

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  dynamic "high_availability" {
    for_each = var.postgres_high_availability ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = "2"
    }
  }

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.db]
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "admins" {
  server_name         = azurerm_postgresql_flexible_server.db.name
  resource_group_name = azurerm_resource_group.app.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = var.postgres_admin_group_object_id
  principal_name      = var.postgres_admin_group_name
  principal_type      = "Group"
}

resource "azurerm_postgresql_flexible_server_configuration" "require_tls" {
  name      = "require_secure_transport"
  server_id = azurerm_postgresql_flexible_server.db.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.db.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.app_name
  server_id = azurerm_postgresql_flexible_server.db.id
  charset   = "UTF8"
  collation = "en_US.utf8"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "db" {
  name                       = "to-log-analytics"
  target_resource_id         = azurerm_postgresql_flexible_server.db.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}
