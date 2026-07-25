output "resource_group_name" {
  value       = azurerm_resource_group.this.name
  description = "Created resource group name."
}

output "ingress_hostname" {
  value       = azurerm_function_app_flex_consumption.this["ingress"].default_hostname
  description = "Ingress hostname; no deployment or request is performed by CI."
}

output "cosmos_endpoint" {
  value       = azurerm_cosmosdb_account.this.endpoint
  description = "Cosmos endpoint, exposed only as Terraform output after a manual deployment."
}

output "function_app_names" {
  value = {
    for name, app in azurerm_function_app_flex_consumption.this : name => app.name
  }
  description = "Function App names for the separate, explicitly approved code-publication step."
}
