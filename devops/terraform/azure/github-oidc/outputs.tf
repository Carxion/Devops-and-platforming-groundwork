output "tenant_id" {
  value = data.azurerm_subscription.current.tenant_id
}

output "subscription_id" {
  value = data.azurerm_subscription.current.subscription_id
}

output "plan_client_id" {
  description = "AZURE_CLIENT_ID for pull request workflows (azure/login)."
  value       = azuread_application.github["plan"].client_id
}

output "apply_client_id" {
  description = "AZURE_CLIENT_ID for jobs that declare the protected apply environment."
  value       = azuread_application.github["apply"].client_id
}
