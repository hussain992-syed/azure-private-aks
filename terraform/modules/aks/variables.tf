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
  description = "ID of the subnet for AKS nodes"
  type        = string
}

variable "vnet_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "private_dns_zone_id" {
  description = "ID of private DNS zone for AKS private cluster (or 'none')"
  type        = string
  default     = "none"
}

variable "api_server_subnet_id" {
  description = "Subnet ID for API server VNet integration"
  type        = string
  default     = ""
}

variable "default_node_count" {
  description = "Number of nodes in default pool"
  type        = number
  default     = 3
}

variable "default_node_size" {
  description = "VM size for default pool"
  type        = string
  default     = "Standard_DC2s_v3"
}

variable "availability_zones" {
  description = "Availability zones for nodes"
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pools"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum node count for auto-scaling"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum node count for auto-scaling"
  type        = number
  default     = 10
}

variable "system_pool_only_critical_addons" {
  description = "Only allow critical addons on system pool"
  type        = bool
  default     = true
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for CoreDNS"
  type        = string
  default     = "10.1.0.10"
}

variable "pod_cidr" {
  description = "CIDR for pods"
  type        = string
  default     = "10.2.0.0/16"
}

variable "admin_group_object_ids" {
  description = "Object IDs of Azure AD groups with cluster admin access"
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for monitoring"
  type        = string
  default     = ""
}

variable "create_workload_node_pool" {
  description = "Create a separate workload node pool"
  type        = bool
  default     = true
}

variable "workload_node_count" {
  description = "Initial node count for workload pool"
  type        = number
  default     = 2
}

variable "workload_node_size" {
  description = "VM size for workload pool"
  type        = string
  default     = "Standard_DC2s_v3"
}

variable "workload_min_count" {
  description = "Minimum node count for workload pool"
  type        = number
  default     = 2
}

variable "workload_max_count" {
  description = "Maximum node count for workload pool"
  type        = number
  default     = 10
}

variable "create_argocd_node_pool" {
  description = "Create a dedicated node pool for ArgoCD"
  type        = bool
  default     = false
}

variable "argocd_node_count" {
  description = "Node count for ArgoCD pool"
  type        = number
  default     = 2
}

variable "argocd_node_size" {
  description = "VM size for ArgoCD pool"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "create_argocd_namespace" {
  description = "Create ArgoCD namespace"
  type        = bool
  default     = true
}

variable "application_namespaces" {
  description = "List of namespaces to create for applications"
  type        = set(string)
  default     = ["production", "staging"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
