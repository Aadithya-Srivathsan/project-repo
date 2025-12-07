output "function_app_name" {
  description = "Name of the Function App"
  value       = azurerm_linux_function_app.func.name
}

output "function_url_base" {
  description = "Base URL of the Function App"
  value       = "https://${azurerm_linux_function_app.func.default_hostname}"
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.kv.name
}
