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
  description = "ID of the private DNS zone for ACR"
  type        = string
}

variable "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet identity"
  type        = string
}

variable "zone_redundancy_enabled" {
  description = "Enable zone redundancy for ACR"
  type        = bool
  default     = true
}

variable "trust_policy_enabled" {
  description = "Enable content trust policy"
  type        = bool
  default     = false
}

variable "retention_days" {
  description = "Number of days to retain untagged manifests"
  type        = number
  default     = 7
}

variable "devops_service_principal_id" {
  description = "Service Principal ID for Azure DevOps (optional)"
  type        = string
  default     = ""
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
