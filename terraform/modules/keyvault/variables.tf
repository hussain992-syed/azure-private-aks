variable "prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet for private endpoint"
  type        = string
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone for Key Vault"
  type        = string
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (recommended for prod)"
  type        = bool
  default     = true
}

variable "devops_service_principal_id" {
  description = "Service Principal ID for Azure DevOps"
  type        = string
  default     = ""
}

variable "aks_identity_principal_id" {
  description = "Principal ID of the AKS cluster identity"
  type        = string
  default     = ""
}

# Map of workload identities to create
# Each entry should have: namespace, service_account_name, aks_oidc_issuer_url
variable "workload_identities" {
  description = "Map of workload identities to create for workload identity federation"
  type = map(object({
    namespace              = string
    service_account_name   = string
    aks_oidc_issuer_url    = string
  }))
  default = {}
}

# Map of secrets to create in Key Vault
variable "secrets" {
  description = "Map of secrets to create in Key Vault"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
