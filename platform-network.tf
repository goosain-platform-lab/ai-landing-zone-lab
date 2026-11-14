#------------------------------------------------------------------------------
# Resource groups: platform pieces split from workloads, as in the source
# environment (network / shared / one per workload).
#------------------------------------------------------------------------------
resource "azurerm_resource_group" "network" {
  name     = "rg-ai-network-${local.suffix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-ai-shared-${local.suffix}"
  location = var.location
  tags     = local.tags
}

#------------------------------------------------------------------------------
# Spoke VNet
#------------------------------------------------------------------------------
resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-ai-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = [var.address_space]
  tags                = local.tags
}

resource "azurerm_subnet" "bastion" {
  # Azure requires this exact name.
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.subnets.bastion]
}

resource "azurerm_subnet" "pe" {
  name                            = "snet-ai-pe-${local.suffix}"
  resource_group_name             = azurerm_resource_group.network.name
  virtual_network_name            = azurerm_virtual_network.spoke.name
  address_prefixes                = [local.subnets.pe]
  default_outbound_access_enabled = false
}

resource "azurerm_subnet" "app" {
  for_each = toset(["rag-app", "stt-app"])

  name                 = "snet-${each.key}-${local.suffix}"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.subnets[each.key]]

  delegation {
    name = "app-service"

    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "jumpbox" {
  name                 = "snet-ai-jumpbox-${local.suffix}"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [local.subnets.jumpbox]
}

#------------------------------------------------------------------------------
# NSGs on every subnet except AzureBastionSubnet (Bastion manages its own
# rules; an NSG there needs a specific rule set).
#------------------------------------------------------------------------------
locals {
  nsg_subnets = {
    pe      = azurerm_subnet.pe.id
    rag-app = azurerm_subnet.app["rag-app"].id
    stt-app = azurerm_subnet.app["stt-app"].id
    jumpbox = azurerm_subnet.jumpbox.id
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = local.nsg_subnets

  name                = "nsg-${each.key}-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags
}

resource "azurerm_network_security_rule" "jumpbox_rdp_from_bastion" {
  name                        = "allow-rdp-from-bastion"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = local.subnets.bastion
  destination_address_prefix  = local.subnets.jumpbox
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.this["jumpbox"].name
}

resource "azurerm_network_security_rule" "jumpbox_deny_vnet_rdp" {
  name                        = "deny-other-rdp"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.this["jumpbox"].name
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsg_subnets

  subnet_id                 = each.value
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

#------------------------------------------------------------------------------
# Hub peering (optional). This is the landing-zone link: shared egress,
# on-premises routes and central DNS come from the hub.
#------------------------------------------------------------------------------
resource "azurerm_virtual_network_peering" "to_hub" {
  count = var.hub_virtual_network_id == null ? 0 : 1

  name                      = "peer-ai-to-hub-${local.suffix}"
  resource_group_name       = azurerm_resource_group.network.name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = var.hub_virtual_network_id
  allow_forwarded_traffic   = true
  use_remote_gateways       = var.use_hub_gateway
}
