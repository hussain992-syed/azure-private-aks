terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }

  # Uncomment to use remote backend for production
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "tfstatestorage"
  #   container_name       = "tfstate"
  #   key                  = "dev.terraform.tfstate"
  #   use_oidc             = true
  # }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

#------------------------------------------------------------------------------
# Local Values
#------------------------------------------------------------------------------
locals {
  environment = "dev"
  prefix      = "privateaks"
  location    = "eastus"
  
  tags = {
    environment = local.environment
    managed_by  = "terraform"
    project     = "private-aks"
    owner       = "platform-team"
  }

  # Workload identities configuration
  # Initially empty, will be configured after AKS is created
  workload_identities = {}

  # Example secrets (in production, use external secret management)
  secrets = {
    # Format: secret-name = "secret-value"
    # In production, inject via CI/CD or use external vault integration
    "database-connection-string" = "placeholder-to-be-updated"
    "api-key"                    = "placeholder-to-be-updated"
  }
}

#------------------------------------------------------------------------------
# Data Sources
#------------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

#------------------------------------------------------------------------------
# Networking Module
#------------------------------------------------------------------------------
module "networking" {
  source = "../../modules/networking"

  prefix     = local.prefix
  environment = local.environment
  location   = local.location

  vnet_address_space     = ["10.0.0.0/16"]
  aks_subnet_prefix      = "10.0.0.0/22"    # ~1000 IPs for AKS nodes
  acr_subnet_prefix      = "10.0.4.0/24"    # 256 IPs for ACR PE
  keyvault_subnet_prefix = "10.0.5.0/24"    # 256 IPs for KV PE
  jumpbox_subnet_prefix  = "10.0.6.0/24"    # 256 IPs for jumpbox/bastion

  # Admin CIDR blocks (configure with your admin IPs)
  admin_cidr_blocks = var.admin_cidr_blocks

  tags = local.tags
}

#------------------------------------------------------------------------------
# Log Analytics Workspace (for monitoring)
#------------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.prefix}-law-${local.environment}"
  resource_group_name = module.networking.resource_group_name
  location            = local.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

#------------------------------------------------------------------------------
# AKS Module
#------------------------------------------------------------------------------
module "aks" {
  source = "../../modules/aks"

  prefix              = local.prefix
  environment         = local.environment
  resource_group_name = module.networking.resource_group_name
  location            = local.location
  subnet_id           = module.networking.aks_subnet_id
  vnet_id             = module.networking.vnet_id

  kubernetes_version = "1.28"
  
  # Private cluster settings
  private_dns_zone_id = "none"  # "none" or custom DNS zone ID
  
  # Default node pool (system pool)
  default_node_count = 2
  default_node_size  = "Standard_D4s_v3"
  
  # Node pool configuration
  enable_auto_scaling = true
  min_node_count      = 2
  max_node_count      = 5
  
  # Azure AD RBAC
  admin_group_object_ids = var.admin_group_object_ids

  # Logging
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # Workload node pool
  create_workload_node_pool = true
  workload_node_count       = 2
  workload_node_size        = "Standard_D4s_v3"
  workload_min_count        = 2
  workload_max_count        = 5

  # ArgoCD configuration
  create_argocd_namespace   = true
  create_argocd_node_pool   = false

  # Application namespaces
  application_namespaces = ["production", "staging", "argocd"]

  tags = local.tags
}

#------------------------------------------------------------------------------
# ACR Module
#------------------------------------------------------------------------------
# Note: ACR is created after AKS because we need the kubelet identity
module "acr" {
  source = "../../modules/acr"

  prefix               = local.prefix
  environment          = local.environment
  resource_group_name  = module.networking.resource_group_name
  location             = local.location
  subnet_id            = module.networking.acr_subnet_id
  private_dns_zone_id  = module.networking.private_dns_zone_acr_id

  # AKS kubelet identity for pull access
  aks_kubelet_identity_object_id = module.aks.aks_kubelet_identity_object_id

  # Azure DevOps access (optional)
  devops_service_principal_id = var.devops_service_principal_id

  # Monitoring
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # Settings
  zone_redundancy_enabled = false  # Disable for dev to save cost
  trust_policy_enabled    = false
  retention_days          = 7

  tags = local.tags
}

#------------------------------------------------------------------------------
# Key Vault Module
#------------------------------------------------------------------------------
module "keyvault" {
  source = "../../modules/keyvault"

  prefix               = local.prefix
  environment          = local.environment
  resource_group_name  = module.networking.resource_group_name
  location             = local.location
  subnet_id            = module.networking.keyvault_subnet_id
  private_dns_zone_id  = module.networking.private_dns_zone_keyvault_id

  # Azure DevOps access
  devops_service_principal_id = var.devops_service_principal_id

  # AKS cluster identity access
  aks_identity_principal_id = module.aks.aks_cluster_identity_principal_id

  # Workload identities for secret access
  workload_identities = local.workload_identities

  # Secrets (update with real values after deployment)
  secrets = local.secrets

  # Monitoring
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # Security
  purge_protection_enabled = false  # Disable for dev (enable for prod)

  tags = local.tags
}

#------------------------------------------------------------------------------
# Provider Configuration for Kubernetes Resources
#------------------------------------------------------------------------------
provider "kubernetes" {
  host                   = module.aks.aks_host
  client_certificate     = base64decode(module.aks.aks_client_certificate)
  client_key             = base64decode(module.aks.aks_client_key)
  cluster_ca_certificate = base64decode(module.aks.aks_cluster_ca_certificate)
}
