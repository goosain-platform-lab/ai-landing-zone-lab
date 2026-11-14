# Workloads land in the platform: they consume the spoke subnets, the shared
# private DNS zones and the central Log Analytics workspace.

#------------------------------------------------------------------------------
# RAG chatbot (module in this repo)
#------------------------------------------------------------------------------
resource "azurerm_resource_group" "rag" {
  count = var.rag_enabled ? 1 : 0

  name     = "rg-rag-${local.suffix}"
  location = var.location
  tags     = merge(local.tags, { workload = "rag" })
}

module "rag" {
  source = "./modules/rag"
  count  = var.rag_enabled ? 1 : 0

  environment         = var.environment
  location            = var.location
  unique_suffix       = var.unique_suffix
  resource_group_name = azurerm_resource_group.rag[0].name
  tags                = merge(local.tags, { workload = "rag" })

  app_subnet_id              = azurerm_subnet.app["rag-app"].id
  private_endpoint_subnet_id = azurerm_subnet.pe.id
  private_dns_zone_ids       = local.private_dns_zone_ids
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  ai_location                            = var.ai_location
  search_sku                             = var.rag_search_sku
  app_service_plan_sku                   = var.rag_app_service_plan_sku
  frontend_public_network_access_enabled = var.rag_frontend_public_network_access_enabled

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.spoke,
    azurerm_subnet_network_security_group_association.this,
  ]
}

#------------------------------------------------------------------------------
# Speech-to-text (versioned module from its own repo)
#------------------------------------------------------------------------------
resource "azurerm_resource_group" "stt" {
  count = var.stt_enabled ? 1 : 0

  name     = "rg-stt-${local.suffix}"
  location = var.location
  tags     = merge(local.tags, { workload = "stt" })
}

module "stt" {
  source = "git::https://github.com/goosain-platform-lab/terraform-azurerm-ai-stt.git?ref=v0.1.0"
  count  = var.stt_enabled ? 1 : 0

  environment         = var.environment
  location            = var.location
  unique_suffix       = var.unique_suffix
  resource_group_name = azurerm_resource_group.stt[0].name
  tags                = merge(local.tags, { workload = "stt" })

  app_subnet_id              = azurerm_subnet.app["stt-app"].id
  private_endpoint_subnet_id = azurerm_subnet.pe.id
  private_dns_zone_ids       = local.private_dns_zone_ids
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  app_service_plan_sku = var.stt_app_service_plan_sku

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.spoke,
    azurerm_subnet_network_security_group_association.this,
  ]
}

#------------------------------------------------------------------------------
# Speech-to-text batch pipeline (versioned module from its own repo). It joins
# the STT App Service plan, so it lives in the STT resource group.
#------------------------------------------------------------------------------
module "stt_batch" {
  source = "git::https://github.com/goosain-platform-lab/terraform-azurerm-ai-stt-batch.git?ref=v0.1.0"
  count  = var.stt_enabled && var.stt_batch_enabled ? 1 : 0

  environment         = var.environment
  location            = var.location
  unique_suffix       = var.unique_suffix
  resource_group_name = azurerm_resource_group.stt[0].name
  tags                = merge(local.tags, { workload = "stt" })

  app_subnet_id              = azurerm_subnet.app["stt-app"].id
  private_endpoint_subnet_id = azurerm_subnet.pe.id
  private_dns_zone_ids       = local.private_dns_zone_ids
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  speech_account_id       = module.stt[0].shared_services.speech_account_id
  speech_endpoint         = module.stt[0].shared_services.speech_endpoint
  speech_principal_id     = module.stt[0].shared_services.speech_principal_id
  translator_account_id   = module.stt[0].shared_services.translator_account_id
  translator_endpoint     = module.stt[0].shared_services.translator_endpoint
  data_storage_account_id = module.stt[0].shared_services.data_storage_account_id
  data_blob_endpoint      = module.stt[0].shared_services.data_blob_endpoint

  use_key_vault = true
  key_vault_id  = module.stt[0].shared_services.key_vault_id

  create_app_service_plan = false
  app_service_plan_id     = module.stt[0].shared_services.app_service_plan_id

  service_bus_sku    = var.stt_service_bus_sku
  openai_deployments = var.stt_openai_deployments
  sql_entra_admin    = var.sql_entra_admin
}

#------------------------------------------------------------------------------
# Private AKS cluster (versioned module from its own repo)
#------------------------------------------------------------------------------
resource "azurerm_resource_group" "aks" {
  count = var.aks_enabled ? 1 : 0

  name     = "rg-aks-${local.suffix}"
  location = var.location
  tags     = merge(local.tags, { workload = "aks" })
}

module "aks" {
  source = "git::https://github.com/goosain-platform-lab/terraform-azurerm-aks.git?ref=v0.1.0"
  count  = var.aks_enabled ? 1 : 0

  environment         = var.environment
  location            = var.location
  unique_suffix       = var.unique_suffix
  resource_group_name = azurerm_resource_group.aks[0].name
  tags                = merge(local.tags, { workload = "aks" })

  node_subnet_id             = azurerm_subnet.aks_nodes.id
  private_endpoint_subnet_id = azurerm_subnet.pe.id
  private_dns_zone_ids       = local.private_dns_zone_ids
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  admin_group_object_ids = var.aks_admin_group_object_ids
  gitops_repository_url  = var.aks_gitops_repository_url

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.spoke,
    azurerm_subnet_network_security_group_association.this,
  ]
}
