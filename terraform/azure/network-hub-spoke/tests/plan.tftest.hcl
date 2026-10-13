# Offline plan with mocked providers: terraform init -backend=false && terraform test
mock_provider "azurerm" {
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet" }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg" }
  }
  mock_resource "azurerm_nat_gateway" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/natGateways/ng" }
  }
  mock_resource "azurerm_public_ip" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/publicIPAddresses/pip" }
  }
  mock_resource "azurerm_route_table" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/routeTables/rt" }
  }
  mock_resource "azurerm_firewall_policy" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/firewallPolicies/afwp" }
  }
  mock_resource "azurerm_firewall" {
    defaults = {
      id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/azureFirewalls/afw"
      ip_configuration = [{ name = "primary", private_ip_address = "10.0.0.4", subnet_id = "", public_ip_address_id = "" }]
    }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log" }
  }
}

variables {
  project         = "example"
  environment     = "dev"
  subscription_id = "00000000-0000-0000-0000-000000000000"
  location        = "eastus2"
  owner           = "platform-team"

  spokes = {
    app = {
      address_space = "10.1.0.0/22"
      subnets = {
        app-integration = { address_prefix = "10.1.0.0/26", delegation = "Microsoft.Web/serverFarms" }
        db              = { address_prefix = "10.1.0.64/26", delegation = "Microsoft.DBforPostgreSQL/flexibleServers" }
      }
    }
    aks = {
      address_space = "10.2.0.0/20"
      subnets = {
        nodes = { address_prefix = "10.2.0.0/22" }
      }
    }
  }
}

run "nat_gateway_egress" {
  command = plan

  assert {
    condition     = length(azurerm_nat_gateway.spoke) == 2 && length(azurerm_subnet_nat_gateway_association.spoke) == 3
    error_message = "Expected a NAT gateway per spoke, associated with every spoke subnet."
  }
  assert {
    condition     = length(azurerm_firewall.hub) == 0 && length(azurerm_route_table.spoke) == 0
    error_message = "No firewall or routes in NAT mode."
  }
  assert {
    condition     = alltrue([for s in azurerm_subnet.spoke : s.default_outbound_access_enabled == false])
    error_message = "Implicit outbound access must be off; egress is explicit."
  }
  assert {
    condition     = azurerm_subnet.spoke["app/db"].delegation[0].service_delegation[0].name == "Microsoft.DBforPostgreSQL/flexibleServers"
    error_message = "Delegations should pass through to the subnet."
  }
  assert {
    condition     = length(azurerm_network_security_group.spoke) == 3
    error_message = "Every spoke subnet gets an NSG."
  }
}

run "firewall_egress" {
  command = plan
  variables {
    egress_mode = "firewall"
  }

  assert {
    condition     = length(azurerm_firewall.hub) == 1 && length(azurerm_nat_gateway.spoke) == 0
    error_message = "Firewall mode should deploy the firewall and no NAT gateways."
  }
  assert {
    condition     = length(azurerm_subnet_route_table_association.spoke) == 3
    error_message = "Every spoke subnet should route through the firewall."
  }
}

run "no_egress" {
  command = plan
  variables {
    egress_mode = "none"
  }

  assert {
    condition     = length(azurerm_firewall.hub) == 0 && length(azurerm_nat_gateway.spoke) == 0
    error_message = "No egress resources in none mode."
  }
}

run "rejects_unknown_egress_mode" {
  command = plan
  variables {
    egress_mode = "internet"
  }
  expect_failures = [var.egress_mode]
}
