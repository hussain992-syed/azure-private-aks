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
  }
}

#------------------------------------------------------------------------------
# Azure Key Vault
#------------------------------------------------------------------------------
resource "azurerm_key_vault" "main" {
  name                = "${var.prefix}-kv-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"  # Premium required for private endpoints

  # Disable public network access - only private endpoint
  public_network_access_enabled = false
  
  # Soft delete and purge protection for security
  soft_delete_retention_days = 90
  purge_protection_enabled   = var.purge_protection_enabled
  
  # RBAC authorization (recommended over access policies)
  enable_rbac_authorization = true

  # Network ACLs - deny all public access
  network_acls {
    default_action = "Deny"
    bypass         = "None"
    # No IP rules - access only via private endpoint
  }

  tags = var.tags
}

data "azurerm_client_config" "current" {}

#------------------------------------------------------------------------------
# Private Endpoint for Key Vault
#------------------------------------------------------------------------------
resource "azurerm_private_endpoint" "keyvault" {
  name                = "${var.prefix}-kv-pe-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "keyvault-private-connection"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection         = false
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# User-Assigned Managed Identity for Workloads
#------------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "workload" {
  for_each            = var.workload_identities
  name                = "${var.prefix}-${each.key}-identity-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

#------------------------------------------------------------------------------
# Key Vault Secrets (example secrets)
#------------------------------------------------------------------------------
# Note: Secrets should be managed via Azure CLI or other secure methods
# Terraform can manage secret metadata but not sensitive values directly
# Use the following command to add secrets:
# az keyvault secret set --vault-name <kv-name> --name <secret-name> --value <secret-value>

# This resource creates placeholders for secret metadata if needed
# For actual secret values, use Azure CLI or Key Vault UI
resource "azurerm_key_vault_secret" "placeholder" {
  count        = length(keys(var.secrets))
  name         = keys(var.secrets)[count.index]
  value        = "placeholder-update-via-azure-cli"
  key_vault_id = azurerm_key_vault.main.id

  # Content type for metadata
  content_type = "text/plain"

  # Tags for organization
  tags = merge(var.tags, {
    managed_by = "terraform"
    purpose    = "application-secret"
  })

  lifecycle {
    ignore_changes = [value]
  }
}

#------------------------------------------------------------------------------
# RBAC Assignments for Key Vault
#------------------------------------------------------------------------------

# Azure DevOps Service Principal - Secret Officer (to manage secrets)
resource "azurerm_role_assignment" "devops_secret_officer" {
  count                = var.devops_service_principal_id != "" ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.devops_service_principal_id
  description          = "Allow Azure DevOps to manage secrets"
}

# AKS Cluster Identity - Certificate User (for TLS certs if needed)
resource "azurerm_role_assignment" "aks_certificate_user" {
  count                = var.aks_identity_principal_id != "" ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Certificate User"
  principal_id         = var.aks_identity_principal_id
  description          = "Allow AKS cluster identity to use certificates"
}

# Workload Identity Role Assignments
resource "azurerm_role_assignment" "workload_secret_user" {
  for_each             = var.workload_identities
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"  # Read-only access to secrets
  principal_id         = azurerm_user_assigned_identity.workload[each.key].principal_id
  description            = "Allow workload ${each.key} to read secrets"
}

#------------------------------------------------------------------------------
# Federated Identity Credentials for Workload Identity
#------------------------------------------------------------------------------
resource "azurerm_federated_identity_credential" "workload" {
  for_each            = var.workload_identities
  name                = "${var.prefix}-${each.key}-federated-cred-${var.environment}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.workload[each.key].id
  issuer              = each.value.aks_oidc_issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:${each.value.service_account_name}"
  audience            = ["api://AzureADTokenExchange"]
}

#------------------------------------------------------------------------------
# Diagnostics Settings
#------------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  count                      = 1
  name                       = "keyvault-diagnostics"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
