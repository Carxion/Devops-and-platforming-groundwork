output "web_app_name" {
  value = azurerm_linux_web_app.app.name
}

output "default_hostname" {
  value = azurerm_linux_web_app.app.default_hostname
}

output "web_app_principal_id" {
  description = "Managed identity of the app; grant it access to other resources."
  value       = azurerm_linux_web_app.app.identity[0].principal_id
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.db.fqdn
}

output "create_app_db_role_sql" {
  description = "Run as a member of the admin group, connected to the postgres database."
  value       = "SELECT * FROM pgaadauth_create_principal('${azurerm_linux_web_app.app.name}', false, false);"
}
