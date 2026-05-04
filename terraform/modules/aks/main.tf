terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

#------------------------------------------------------------------------------
# User-Assigned Managed Identity for AKS Control Plane
#------------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "aks_control_plane" {
  name                = "${var.prefix}-aks-control-plane-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

#------------------------------------------------------------------------------
# AKS Cluster
#------------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.prefix}-aks-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
 # kubernetes_version  = var.kubernetes_version
  dns_prefix          = "${var.prefix}-aks-${var.environment}"
  node_resource_group = "${var.prefix}-aks-nodes-${var.environment}"

  # Private cluster configuration - NO public API endpoint
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id = "System"
  
  # Private DNS zone - either "None" (bring your own) or "System"
  private_dns_zone_id = var.private_dns_zone_id != "" ? var.private_dns_zone_id : "System"

  # Identity configuration
  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.aks_control_plane.id
    ]
  }

  # Default node pool
  default_node_pool {
    name                = "default"
    node_count          = var.default_node_count
    vm_size             = var.default_node_size
    vnet_subnet_id      = var.subnet_id
    os_disk_size_gb     = 128
    os_disk_type        = "Managed"
    os_sku              = "Ubuntu"
    type                = "VirtualMachineScaleSets"
    zones               = null
    enable_auto_scaling = var.enable_auto_scaling
    min_count           = var.enable_auto_scaling ? var.min_node_count : null
    max_count           = var.enable_auto_scaling ? var.max_node_count : null

    # Node labels
    node_labels = {
      environment = var.environment
      workload    = "system"
    }

    # Only CriticalAddonsAllowed taint for system pool
    only_critical_addons_enabled = var.system_pool_only_critical_addons
  }

  # Network profile - Azure CNI with network policies
  network_profile {
    network_plugin      = "azure"
    network_policy      = "calico"  # or "azure" for Azure Network Policy
    network_plugin_mode = "overlay"
    load_balancer_sku   = "standard"
    
    # Service and pod CIDRs
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
    pod_cidr           = var.pod_cidr

    # Outbound type - load balancer for custom VNet configuration
    outbound_type = "loadBalancer"
  }

  # RBAC with Azure AD
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  # Enable OIDC issuer for workload identity
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # API server access profile - authorized IP ranges
  api_server_access_profile {
    # No authorized IP ranges - private cluster only
    # Subnet ID for private cluster communication
    subnet_id = var.api_server_subnet_id != "" ? var.api_server_subnet_id : null
  }

  # Security settings
  local_account_disabled = true  # Disable local accounts, use AAD only

  # Auto-upgrade profile
  maintenance_window {
    allowed {
      day   = "Saturday"
      hours = [22, 23, 0, 1, 2]
    }
  }

  # Key Vault secrets provider (CSI driver)
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Microsoft Defender for Containers
  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Monitoring
  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  # Storage profile
  storage_profile {
    blob_driver_enabled = true
    disk_driver_enabled = true
    file_driver_enabled = true
    snapshot_controller_enabled = true
  }

  tags = var.tags

  depends_on = [
    azurerm_role_assignment.aks_network_contributor
  ]
}

#------------------------------------------------------------------------------
# Role Assignments for AKS Control Plane
#------------------------------------------------------------------------------
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
  description          = "Allow AKS to manage network resources"
}

#------------------------------------------------------------------------------
# Additional Node Pools
#------------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  count                 = var.create_workload_node_pool ? 1 : 0
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.workload_node_size
  node_count            = var.workload_node_count
  vnet_subnet_id        = var.subnet_id
  os_disk_size_gb       = 128
  os_disk_type          = "Managed"
  os_type               = "Linux"
  zones                 = null
  enable_auto_scaling   = var.enable_auto_scaling
  min_count             = var.enable_auto_scaling ? var.workload_min_count : null
  max_count             = var.enable_auto_scaling ? var.workload_max_count : null

  node_labels = {
    environment = var.environment
    workload    = "app"
  }

  node_taints = []

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "argocd" {
  count                 = var.create_argocd_node_pool ? 1 : 0
  name                  = "argocd"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.argocd_node_size
  node_count            = var.argocd_node_count
  vnet_subnet_id        = var.subnet_id
  os_disk_size_gb       = 128
  os_type               = "Linux"

  node_labels = {
    environment = var.environment
    workload    = "argocd"
  }

  node_taints = [
    "dedicated=argocd:NoSchedule"
  ]

  tags = var.tags
}

#------------------------------------------------------------------------------
# Kubernetes Namespace for ArgoCD
#------------------------------------------------------------------------------
resource "kubernetes_namespace" "argocd" {
  count = var.create_argocd_namespace ? 1 : 0
  metadata {
    name = "argocd"
    labels = {
      environment = var.environment
      managed_by  = "terraform"
    }
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}

#------------------------------------------------------------------------------
# Kubernetes Namespace for Applications
#------------------------------------------------------------------------------
resource "kubernetes_namespace" "applications" {
  for_each = var.application_namespaces
  metadata {
    name = each.value
    labels = {
      environment = var.environment
      managed_by  = "terraform"
    }
  }

  depends_on = [azurerm_kubernetes_cluster.main]
}
