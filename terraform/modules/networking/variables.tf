variable "prefix" {
  description = "Prefix for resource naming"
  type        = string
  default     = "privateaks"
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "vnet_address_space" {
  description = "Address space for VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "Address prefix for AKS subnet"
  type        = string
  default     = "10.0.0.0/22"
}

variable "acr_subnet_prefix" {
  description = "Address prefix for ACR private endpoint subnet"
  type        = string
  default     = "10.0.4.0/24"
}

variable "keyvault_subnet_prefix" {
  description = "Address prefix for Key Vault private endpoint subnet"
  type        = string
  default     = "10.0.5.0/24"
}

variable "jumpbox_subnet_prefix" {
  description = "Address prefix for jumpbox/bastion subnet"
  type        = string
  default     = "10.0.6.0/24"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed for admin access"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
