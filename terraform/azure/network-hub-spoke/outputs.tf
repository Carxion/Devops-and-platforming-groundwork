output "resource_group_name" {
  value = azurerm_resource_group.network.name
}

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "spoke_vnet_ids" {
  value = { for k, v in azurerm_virtual_network.spoke : k => v.id }
}

output "subnet_ids" {
  description = "Spoke subnet IDs keyed by \"<spoke>/<subnet>\"."
  value       = { for k, v in azurerm_subnet.spoke : k => v.id }
}

output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.shared.id
}

output "firewall_private_ip" {
  value = var.egress_mode == "firewall" ? azurerm_firewall.hub[0].ip_configuration[0].private_ip_address : null
}

output "egress_mode" {
  description = "Set aks-cluster's outbound_type to match: nat_gateway -> userAssignedNATGateway, firewall -> userDefinedRouting."
  value       = var.egress_mode
}

output "nat_public_ips" {
  description = "Egress IPs per spoke, for allow-listing at partners and SaaS providers."
  value       = { for k, v in azurerm_public_ip.nat : k => v.ip_address }
}
