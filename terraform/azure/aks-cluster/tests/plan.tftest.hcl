# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = { tenant_id = "00000000-0000-0000-0000-000000000001" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id"
      principal_id = "00000000-0000-0000-0000-000000000004"
    }
  }
}

variables {
  project                    = "example"
  environment                = "dev"
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  location                   = "eastus2"
  owner                      = "platform-team"
  kubernetes_version         = "1.34"
  node_subnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/nodes"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log"
  admin_group_object_ids     = ["00000000-0000-0000-0000-000000000005"]
}

run "entra_only_access" {
  command = plan

  assert {
    condition     = azurerm_kubernetes_cluster.main.local_account_disabled
    error_message = "Local accounts must be disabled."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.main.azure_active_directory_role_based_access_control[0].azure_rbac_enabled
    error_message = "Azure RBAC for Kubernetes should be on."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.main.workload_identity_enabled && azurerm_kubernetes_cluster.main.oidc_issuer_enabled
    error_message = "Workload identity should be on."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.main.default_node_pool[0].only_critical_addons_enabled
    error_message = "System pool should run only critical add-ons."
  }
}

run "authorized_ranges_only_for_public_api" {
  command = plan
  variables {
    api_server_authorized_ip_ranges = ["203.0.113.0/24"]
  }

  assert {
    condition     = length(azurerm_kubernetes_cluster.main.api_server_access_profile) == 1
    error_message = "Authorized IP ranges should apply to a public API server."
  }
}

run "private_cluster_ignores_ranges" {
  command = plan
  variables {
    private_cluster                 = true
    api_server_authorized_ip_ranges = ["203.0.113.0/24"]
  }

  assert {
    condition     = azurerm_kubernetes_cluster.main.private_cluster_enabled && length(azurerm_kubernetes_cluster.main.api_server_access_profile) == 0
    error_message = "Private clusters don't use authorized IP ranges."
  }
}
