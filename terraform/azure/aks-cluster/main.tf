# AKS cluster with Entra ID authentication and Azure RBAC for Kubernetes
# (local accounts disabled), workload identity for pods, Azure CNI overlay
# with Cilium network policy, automatic patch upgrades, Azure Policy, Key
# Vault secrets provider, and Container Insights. A small system pool runs
# only critical add-ons; workloads go to an autoscaling user pool.

data "azurerm_client_config" "current" {}

locals {
  name = "${var.project}-${var.environment}"

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Stack       = "aks-cluster"
  })
}

resource "azurerm_resource_group" "aks" {
  name     = "rg-${local.name}-aks"
  location = var.location
  tags     = local.tags
}

# User-assigned control plane identity, so its subnet permission can be
# granted before the cluster exists.
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-${local.name}-aks"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "subnet" {
  scope                = var.node_subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_kubernetes_cluster" "main" {
  #checkov:skip=CKV_AZURE_117:Platform-managed disk encryption keys; add a disk encryption set if your program requires customer-managed keys.
  #checkov:skip=CKV_AZURE_115:Private cluster is configurable (private_cluster); authorized IP ranges apply when it is off.
  #checkov:skip=CKV_AZURE_6:Authorized IP ranges are configurable (api_server_authorized_ip_ranges).
  name                = "aks-${local.name}"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  dns_prefix          = "aks-${local.name}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = "Standard" # financially backed API server SLA

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  local_account_disabled            = true
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  azure_policy_enabled              = true
  image_cleaner_enabled             = true
  image_cleaner_interval_hours      = 48
  private_cluster_enabled           = var.private_cluster

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
    tenant_id              = data.azurerm_client_config.current.tenant_id
  }

  dynamic "api_server_access_profile" {
    for_each = !var.private_cluster && length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    vnet_subnet_id               = var.node_subnet_id
    zones                        = ["1", "2", "3"]
    auto_scaling_enabled         = true
    min_count                    = 3
    max_count                    = 5
    max_pods                     = 110
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = var.os_disk_size_gb
    os_sku                       = "AzureLinux"
    host_encryption_enabled      = var.host_encryption
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "systemtmp"

    upgrade_settings {
      max_surge = "33%"
    }
  }

  # Manual: the node pools below with the cluster autoscaler. "Auto" switches
  # to node auto-provisioning (Karpenter), which manages nodes itself.
  node_provisioning_profile {
    mode = "Manual"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    outbound_type       = var.outbound_type
    load_balancer_sku   = "standard"
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Sunday"
    start_time  = "02:00"
    duration    = 4
    utc_offset  = "+00:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Sunday"
    start_time  = "06:00"
    duration    = 4
    utc_offset  = "+00:00"
  }

  tags = local.tags

  depends_on = [azurerm_role_assignment.subnet]
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                    = "user"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.main.id
  vm_size                 = var.user_node_vm_size
  vnet_subnet_id          = var.node_subnet_id
  zones                   = ["1", "2", "3"]
  mode                    = "User"
  auto_scaling_enabled    = true
  min_count               = var.user_node_min_count
  max_count               = var.user_node_max_count
  max_pods                = 110
  os_disk_type            = "Ephemeral"
  os_disk_size_gb         = var.os_disk_size_gb
  os_sku                  = "AzureLinux"
  host_encryption_enabled = var.host_encryption

  upgrade_settings {
    max_surge = "33%"
  }

  tags = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                           = "to-log-analytics"
  target_resource_id             = azurerm_kubernetes_cluster.main.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "guard"
  }

  enabled_log {
    category = "kube-apiserver"
  }
}
