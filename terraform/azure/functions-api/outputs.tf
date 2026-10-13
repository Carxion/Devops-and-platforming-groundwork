output "function_app_name" {
  value = azurerm_function_app_flex_consumption.api.name
}

output "api_base_url" {
  value = "https://${azurerm_function_app_flex_consumption.api.default_hostname}/api"
}

output "cosmos_endpoint" {
  value = azurerm_cosmosdb_account.api.endpoint
}

output "publish_command" {
  value = "cd src && func azure functionapp publish ${azurerm_function_app_flex_consumption.api.name}"
}
