output "tenant_id" {
  description = "ARM_TENANT_ID for the pipeline."
  value       = data.azurerm_subscription.current.tenant_id
}

output "subscription_id" {
  description = "ARM_SUBSCRIPTION_ID for the pipeline."
  value       = data.azurerm_subscription.current.subscription_id
}

output "plan_client_id" {
  description = "ARM_CLIENT_ID for plan jobs."
  value       = azuread_application.gitlab["plan"].client_id
}

output "apply_client_id" {
  description = "ARM_CLIENT_ID for the apply job, in a CI/CD variable protected to the apply branch."
  value       = azuread_application.gitlab["apply"].client_id
}
