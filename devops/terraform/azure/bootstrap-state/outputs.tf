output "resource_group_name" {
  value = azurerm_resource_group.state.name
}

output "storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "storage_account_id" {
  value = azurerm_storage_account.state.id
}

output "container_name" {
  value = azurerm_storage_container.state.name
}

output "backend_config" {
  description = "Paste into a stack's backend.hcl, changing the key per stack and environment."
  value       = <<-EOT
    resource_group_name  = "${azurerm_resource_group.state.name}"
    storage_account_name = "${azurerm_storage_account.state.name}"
    container_name       = "${azurerm_storage_container.state.name}"
    key                  = "<stack>/<environment>/terraform.tfstate"
    use_azuread_auth     = true
  EOT
}
