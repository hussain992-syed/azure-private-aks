output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "private_endpoint_ip" {
  description = "Private IP address of the Key Vault private endpoint"
  value       = azurerm_private_endpoint.keyvault.private_service_connection[0].private_ip_address
}

output "workload_identity_ids" {
  description = "Map of workload identity IDs"
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.id }
}

output "workload_identity_client_ids" {
  description = "Map of workload identity client IDs"
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.client_id }
}

output "workload_identity_principal_ids" {
  description = "Map of workload identity principal IDs"
  value       = { for k, v in azurerm_user_assigned_identity.workload : k => v.principal_id }
}
