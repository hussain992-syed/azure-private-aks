output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.networking.resource_group_name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

output "aks_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.aks_name
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = module.aks.oidc_issuer_url
}

output "acr_login_server" {
  description = "ACR login server URL"
  value       = module.acr.acr_login_server
}

output "acr_name" {
  description = "ACR name"
  value       = module.acr.acr_name
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = module.keyvault.key_vault_name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.keyvault.key_vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "workload_identity_ids" {
  description = "Workload identity IDs"
  value       = module.keyvault.workload_identity_ids
}

output "workload_identity_client_ids" {
  description = "Workload identity client IDs"
  value       = module.keyvault.workload_identity_client_ids
}

output "private_endpoint_ips" {
  description = "Private endpoint IPs"
  value = {
    acr      = module.acr.private_endpoint_ip
    keyvault = module.keyvault.private_endpoint_ip
  }
}

# Sensitive outputs - for use with kubectl
output "kube_config_raw" {
  description = "Raw kubeconfig (sensitive)"
  value       = module.aks.aks_kube_config_raw
  sensitive   = true
}
