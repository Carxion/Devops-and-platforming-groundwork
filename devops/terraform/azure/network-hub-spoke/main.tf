# Hub-and-spoke network: a hub VNet with the reserved subnets for Azure
# Firewall, Bastion, and a VPN/ExpressRoute gateway, plus spoke VNets
# peered to it. Every spoke subnet gets an NSG. Firewall and Bastion are
# optional. Spoke egress goes through a NAT gateway, the firewall, or
# nowhere, set by egress_mode.
# Also creates the shared Log Analytics workspace other stacks send to.

locals {
  name     = "${var.project}-${var.environment}"
  firewall = var.egress_mode == "firewall"
  nat      = var.egress_mode == "nat_gateway"

  tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Stack       = "network-hub-spoke"
  })

  # Hub /22 -> firewall /26, bastion /26, gateway /27.
  hub_subnets = {
    AzureFirewallSubnet = cidrsubnet(var.hub_address_space, 4, 0)
    AzureBastionSubnet  = cidrsubnet(var.hub_address_space, 4, 1)
    GatewaySubnet       = cidrsubnet(var.hub_address_space, 5, 4)
  }

  spoke_subnets = merge([
    for spoke, cfg in var.spokes : {
      for subnet, s in cfg.subnets : "${spoke}/${subnet}" => merge(s, { spoke = spoke, name = subnet })
    }
  ]...)

  # Actions each common delegation needs.
  delegation_actions = {
    "Microsoft.Web/serverFarms"                 = ["Microsoft.Network/virtualNetworks/subnets/action"]
    "Microsoft.DBforPostgreSQL/flexibleServers" = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    "Microsoft.App/environments"                = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
}

resource "azurerm_resource_group" "network" {
  name     = "rg-${local.name}-network"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "shared" {
  name                = "log-${local.name}"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

# --- Hub ---------------------------------------------------------------------

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${local.name}-hub"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = [var.hub_address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "hub" {
  #checkov:skip=CKV2_AZURE_31:Firewall and gateway subnets don't support NSGs; a Bastion NSG needs Azure's required rule set, added when enable_bastion is used.
  for_each = local.hub_subnets

  name                            = each.key
  resource_group_name             = azurerm_resource_group.network.name
  virtual_network_name            = azurerm_virtual_network.hub.name
  address_prefixes                = [each.value]
  default_outbound_access_enabled = false
}

resource "azurerm_public_ip" "firewall" {
  count = local.firewall ? 1 : 0

  name                = "pip-${local.name}-fw"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

# Starts with no rule collections, so all spoke egress is denied. Add
# application and network rule collections for what workloads need.
resource "azurerm_firewall_policy" "hub" {
  #checkov:skip=CKV_AZURE_220:IDPS requires the Premium SKU; switch sku to Premium and add intrusion_detection if your program requires it.
  count = local.firewall ? 1 : 0

  name                     = "afwp-${local.name}"
  resource_group_name      = azurerm_resource_group.network.name
  location                 = azurerm_resource_group.network.location
  sku                      = "Standard"
  threat_intelligence_mode = "Deny"
  tags                     = local.tags

  dns {
    proxy_enabled = true
  }
}

resource "azurerm_firewall" "hub" {
  #checkov:skip=CKV_AZURE_216:Threat intelligence is set to Deny on the attached firewall policy, which overrides the firewall setting.
  count = local.firewall ? 1 : 0

  name                = "afw-${local.name}"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.hub[0].id
  zones               = ["1", "2", "3"]
  tags                = local.tags

  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.hub["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count = local.firewall ? 1 : 0

  name                           = "to-log-analytics"
  target_resource_id             = azurerm_firewall.hub[0].id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.shared.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_public_ip" "bastion" {
  count = var.enable_bastion ? 1 : 0

  name                = "pip-${local.name}-bastion"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_bastion_host" "hub" {
  count = var.enable_bastion ? 1 : 0

  name                = "bas-${local.name}"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku                 = "Standard"
  tags                = local.tags

  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.hub["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# --- Spokes ------------------------------------------------------------------

resource "azurerm_virtual_network" "spoke" {
  for_each = var.spokes

  name                = "vnet-${local.name}-${each.key}"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  address_space       = [each.value.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "spoke" {
  for_each = local.spoke_subnets

  name                            = each.value.name
  resource_group_name             = azurerm_resource_group.network.name
  virtual_network_name            = azurerm_virtual_network.spoke[each.value.spoke].name
  address_prefixes                = [each.value.address_prefix]
  default_outbound_access_enabled = false

  dynamic "delegation" {
    for_each = each.value.delegation == null ? [] : [each.value.delegation]
    content {
      name = replace(delegation.value, "/", "-")
      service_delegation {
        name    = delegation.value
        actions = lookup(local.delegation_actions, delegation.value, null)
      }
    }
  }
}

# One NSG per subnet with Azure's default rules. Add explicit rules per
# workload; the defaults allow traffic within the VNet and peered VNets.
resource "azurerm_network_security_group" "spoke" {
  for_each = local.spoke_subnets

  name                = "nsg-${local.name}-${each.value.spoke}-${each.value.name}"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = local.spoke_subnets

  subnet_id                 = azurerm_subnet.spoke[each.key].id
  network_security_group_id = azurerm_network_security_group.spoke[each.key].id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  use_remote_gateways       = false
}

# --- Egress: NAT gateway -----------------------------------------------------

resource "azurerm_public_ip" "nat" {
  for_each = local.nat ? var.spokes : {}

  name                = "pip-${local.name}-${each.key}-nat"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = local.tags
}

resource "azurerm_nat_gateway" "spoke" {
  for_each = local.nat ? var.spokes : {}

  name                = "ng-${local.name}-${each.key}"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "spoke" {
  for_each = local.nat ? var.spokes : {}

  nat_gateway_id       = azurerm_nat_gateway.spoke[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
}

resource "azurerm_subnet_nat_gateway_association" "spoke" {
  for_each = local.nat ? local.spoke_subnets : {}

  subnet_id      = azurerm_subnet.spoke[each.key].id
  nat_gateway_id = azurerm_nat_gateway.spoke[each.value.spoke].id
}

# --- Egress: firewall --------------------------------------------------------

resource "azurerm_route_table" "spoke" {
  for_each = local.firewall ? var.spokes : {}

  name                          = "rt-${local.name}-${each.key}"
  resource_group_name           = azurerm_resource_group.network.name
  location                      = azurerm_resource_group.network.location
  bgp_route_propagation_enabled = false
  tags                          = local.tags

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub[0].ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke" {
  for_each = local.firewall ? local.spoke_subnets : {}

  subnet_id      = azurerm_subnet.spoke[each.key].id
  route_table_id = azurerm_route_table.spoke[each.value.spoke].id
}
