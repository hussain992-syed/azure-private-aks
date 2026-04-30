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
# Resource Group
#------------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg-${var.environment}"
  location = var.location
  tags     = var.tags
}

#------------------------------------------------------------------------------
# Virtual Network
#------------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

#------------------------------------------------------------------------------
# Subnets
#------------------------------------------------------------------------------
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_prefix]

  # Required for AKS
  private_endpoint_network_policies_enabled = false
  service_endpoints                           = ["Microsoft.KeyVault"]
}

resource "azurerm_subnet" "acr" {
  name                 = "acr-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.acr_subnet_prefix]

  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet" "keyvault" {
  name                 = "keyvault-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.keyvault_subnet_prefix]

  private_endpoint_network_policies_enabled = true
}

resource "azurerm_subnet" "jumpbox" {
  name                 = "jumpbox-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.jumpbox_subnet_prefix]

  # Public IP required for jumpbox access
}

#------------------------------------------------------------------------------
# Network Security Groups
#------------------------------------------------------------------------------
resource "azurerm_network_security_group" "aks" {
  name                = "${var.prefix}-aks-nsg-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow inter-node communication
  security_rule {
    name                       = "AllowInterNode"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.aks_subnet_prefix
    destination_address_prefix = var.aks_subnet_prefix
  }

  # Allow Azure Load Balancer health probes
  security_rule {
    name                       = "AllowAzureLB"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_network_security_group" "jumpbox" {
  name                = "${var.prefix}-jumpbox-nsg-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow SSH from specific admin IPs only
  dynamic "security_rule" {
    for_each = var.admin_cidr_blocks
    content {
      name                       = "AllowSSH-${security_rule.key}"
      priority                   = 100 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# NSG-Subnet Associations
#------------------------------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "jumpbox" {
  subnet_id                 = azurerm_subnet.jumpbox.id
  network_security_group_id = azurerm_network_security_group.jumpbox.id
}

#------------------------------------------------------------------------------
# Private DNS Zones
#------------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "acr-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "keyvault-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

#------------------------------------------------------------------------------
# Route Table (for forced tunneling if needed)
#------------------------------------------------------------------------------
resource "azurerm_route_table" "main" {
  name                          = "${var.prefix}-rt-${var.environment}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  disable_bgp_route_propagation = false

  # Default route for internet traffic (can be modified for forced tunneling)
  route {
    name           = "internet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }

  tags = var.tags
}

resource "azurerm_subnet_route_table_association" "aks" {
  subnet_id      = azurerm_subnet.aks.id
  route_table_id = azurerm_route_table.main.id
}
