#------------------------------------------------------------------------------
# Central Log Analytics workspace (Entra-only access)
#------------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "this" {
  name                         = "log-ai-${local.suffix}"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.shared.name
  sku                          = "PerGB2018"
  retention_in_days            = var.log_retention_days
  daily_quota_gb               = var.log_daily_quota_gb
  local_authentication_enabled = false
  tags                         = local.tags
}

#------------------------------------------------------------------------------
# Private access: Bastion + Windows jumpbox
#------------------------------------------------------------------------------
resource "azurerm_public_ip" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name                = "pip-bas-ai-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_bastion_host" "this" {
  count = var.bastion_enabled ? 1 : 0

  name                = "bas-ai-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  sku                 = var.bastion_sku
  copy_paste_enabled  = true
  tunneling_enabled   = var.bastion_sku != "Basic"
  tags                = local.tags

  ip_configuration {
    name                 = "default"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# The local admin password is generated, kept only in Terraform state (which
# HCP Terraform encrypts) and never output. Day-to-day sign-in is with Entra ID.
resource "random_password" "jumpbox" {
  count = var.jumpbox_enabled ? 1 : 0

  length           = 24
  special          = true
  override_special = "!@#%*()-_=+"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "azurerm_network_interface" "jumpbox" {
  count = var.jumpbox_enabled ? 1 : 0

  name                = "nic-vm-ai-jump-${local.suffix}"
  location            = var.location
  resource_group_name = azurerm_resource_group.shared.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.jumpbox.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "jumpbox" {
  count = var.jumpbox_enabled ? 1 : 0

  name                  = "vm-ai-jump-${local.suffix}"
  computer_name         = "aijump${var.environment}"
  location              = var.location
  resource_group_name   = azurerm_resource_group.shared.name
  size                  = var.jumpbox_size
  admin_username        = "labadmin"
  admin_password        = random_password.jumpbox[0].result
  network_interface_ids = [azurerm_network_interface.jumpbox[0].id]
  secure_boot_enabled   = true
  vtpm_enabled          = true
  patch_mode            = "AutomaticByPlatform"
  tags                  = local.tags

  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

# Entra ID sign-in, so nobody needs the local password.
resource "azurerm_virtual_machine_extension" "jumpbox_entra_login" {
  count = var.jumpbox_enabled ? 1 : 0

  name                       = "AADLoginForWindows"
  virtual_machine_id         = azurerm_windows_virtual_machine.jumpbox[0].id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = local.tags
}

resource "azurerm_role_assignment" "jumpbox_login" {
  count = var.jumpbox_enabled && var.jumpbox_admin_principal_id != null ? 1 : 0

  scope                = azurerm_windows_virtual_machine.jumpbox[0].id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = var.jumpbox_admin_principal_id
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "jumpbox" {
  count = var.jumpbox_enabled && var.jumpbox_auto_shutdown_time != null ? 1 : 0

  virtual_machine_id    = azurerm_windows_virtual_machine.jumpbox[0].id
  location              = var.location
  enabled               = true
  daily_recurrence_time = var.jumpbox_auto_shutdown_time
  timezone              = "South Africa Standard Time"
  tags                  = local.tags

  notification_settings {
    enabled = false
  }
}
