variable "admin_cidr_blocks" {
  description = "List of CIDR blocks allowed for admin access (SSH, etc.)"
  type        = list(string)
  default     = []
  
  validation {
    condition     = length(var.admin_cidr_blocks) > 0
    error_message = "At least one admin CIDR block must be specified for security."
  }
}

variable "admin_group_object_ids" {
  description = "Object IDs of Azure AD groups with cluster admin access"
  type        = list(string)
  default     = []
}

variable "devops_service_principal_id" {
  description = "Service Principal Object ID for Azure DevOps to access ACR and Key Vault"
  type        = string
  default     = ""
}

variable "terraform_sp_object_id" {
  description = "Service Principal Object ID running Terraform (for Key Vault access during deployment)"
  type        = string
  default     = ""
}
