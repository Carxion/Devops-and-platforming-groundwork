# Remote state for every other Azure stack: a storage account with shared
# keys disabled (Entra ID auth only), blob versioning and soft delete, TLS
# 1.2, and a delete lock. Locking uses blob leases, which the azurerm
# backend handles automatically.

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  tags = merge(var.tags, {
    Project   = var.project
    Owner     = var.owner
    ManagedBy = "terraform"
    Stack     = "bootstrap-state"
  })

  contributors = toset(concat([data.azurerm_client_config.current.object_id], var.state_contributor_principal_ids))
}

resource "azurerm_resource_group" "state" {
  name     = "rg-${var.project}-tfstate"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "state" {
  #checkov:skip=CKV_AZURE_35:Default action is Deny whenever allowed_ip_ranges is set; checkov can't evaluate the conditional.
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed keys with infrastructure encryption; add a customer-managed key if your program requires one.
  #checkov:skip=CKV2_AZURE_33:Private endpoint depends on where runners live; see allowed_ip_ranges and the README.
  #checkov:skip=CKV_AZURE_59:Public network access is restricted by the firewall rules below; private endpoint is optional.
  #checkov:skip=CKV_AZURE_33:Queue service is unused.
  #checkov:skip=CKV_AZURE_206:Replication is configurable; ZRS is the default.
  name                     = "st${var.project}tfstate${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replication_type

  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  public_network_access             = "Enabled"

  network_rules {
    default_action = length(var.allowed_ip_ranges) > 0 ? "Deny" : "Allow"
    ip_rules       = var.allowed_ip_ranges
    bypass         = ["AzureServices"]
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  tags = local.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "state" {
  #checkov:skip=CKV2_AZURE_21:Blob read logging is configured through diagnostic settings at the program level.
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_role_assignment" "state_contributors" {
  for_each = local.contributors

  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
}

resource "azurerm_management_lock" "state" {
  name       = "do-not-delete"
  scope      = azurerm_storage_account.state.id
  lock_level = "CanNotDelete"
  notes      = "Holds Terraform state for ${var.project}."
}
