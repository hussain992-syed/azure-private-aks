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
# Azure Container Registry
#------------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  name                = "${var.prefix}acr${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium"  # Required for private endpoints
  admin_enabled       = false      # Disable admin account (use AAD/identity)
  
  # Security settings
  public_network_access_enabled = false  # Disable public access
  zone_redundancy_enabled       = var.zone_redundancy_enabled
  
  # Trust policy for signed images (optional)
  trust_policy {
    enabled = var.trust_policy_enabled
  }

  # Content trust (ACR Tasks)
  dynamic "retention_policy" {
    for_each = var.retention_days > 0 ? [1] : []
    content {
      enabled = true
      days    = var.retention_days
    }
  }

  # Network rule set - deny all public access
  network_rule_set {
    default_action = "Deny"
    # No IP rules - access only via private endpoint
  }

  # Identity for Key Vault access (if using CMK)
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Private Endpoint for ACR
#------------------------------------------------------------------------------
resource "azurerm_private_endpoint" "acr" {
  name                = "${var.prefix}-acr-pe-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "acr-private-connection"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# ACR Role Assignments for AKS
#------------------------------------------------------------------------------
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.aks_kubelet_identity_object_id
  description          = "Allow AKS kubelet to pull images from ACR"
}

#------------------------------------------------------------------------------
# Azure DevOps Service Principal Access (if provided)
#------------------------------------------------------------------------------
resource "azurerm_role_assignment" "devops_acr_push" {
  count                = var.devops_service_principal_id != "" ? 1 : 0
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = var.devops_service_principal_id
  description          = "Allow Azure DevOps to push images to ACR"
}

#------------------------------------------------------------------------------
# Diagnostics Settings
#------------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "acr-diagnostics"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
