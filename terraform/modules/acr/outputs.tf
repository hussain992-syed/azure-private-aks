output "acr_id" {
  description = "ID of the Azure Container Registry"
  value       = azurerm_container_registry.main.id
}

output "acr_login_server" {
  description = "Login server URL for ACR"
  value       = azurerm_container_registry.main.login_server
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "private_endpoint_ip" {
  description = "Private IP address of the ACR private endpoint"
  value       = azurerm_private_endpoint.acr.private_service_connection[0].private_ip_address
}
