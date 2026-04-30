output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "acr_subnet_id" {
  description = "ID of the ACR subnet"
  value       = azurerm_subnet.acr.id
}

output "keyvault_subnet_id" {
  description = "ID of the Key Vault subnet"
  value       = azurerm_subnet.keyvault.id
}

output "jumpbox_subnet_id" {
  description = "ID of the jumpbox subnet"
  value       = azurerm_subnet.jumpbox.id
}

output "private_dns_zone_acr_id" {
  description = "ID of the ACR private DNS zone"
  value       = azurerm_private_dns_zone.acr.id
}

output "private_dns_zone_keyvault_id" {
  description = "ID of the Key Vault private DNS zone"
  value       = azurerm_private_dns_zone.keyvault.id
}

output "aks_nsg_id" {
  description = "ID of the AKS network security group"
  value       = azurerm_network_security_group.aks.id
}
