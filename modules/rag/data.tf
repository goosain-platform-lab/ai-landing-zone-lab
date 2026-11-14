#------------------------------------------------------------------------------
# Key Vault (RBAC, private). Terraform never writes secret values.
#------------------------------------------------------------------------------
resource "azurerm_key_vault" "this" {
  name                          = local.names.key_vault
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = var.key_vault_purge_protection_enabled
  soft_delete_retention_days    = 7
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }
}

#------------------------------------------------------------------------------
# Storage: documents to index, plus one host account per Function App.
# Shared keys are off everywhere.
#------------------------------------------------------------------------------
locals {
  storage = {
    docs = local.names.storage_docs
    orch = local.names.storage_orch
    ing  = local.names.storage_ing
  }
}

resource "azurerm_storage_account" "this" {
  for_each = local.storage

  name                             = each.value
  location                         = var.location
  resource_group_name              = var.resource_group_name
  account_kind                     = "StorageV2"
  account_tier                     = "Standard"
  account_replication_type         = var.storage_replication_type
  min_tls_version                  = "TLS1_2"
  https_traffic_only_enabled       = true
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  local_user_enabled               = false
  public_network_access            = "Disabled"
  tags                             = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_container" "docs" {
  for_each = toset([local.docs_container, local.docs_images_container, "nl2sql"])

  name                  = each.value
  storage_account_id    = azurerm_storage_account.this["docs"].id
  container_access_type = "private"
}

#------------------------------------------------------------------------------
# Cosmos DB: conversation history (Entra-only, private).
#------------------------------------------------------------------------------
resource "azurerm_cosmosdb_account" "this" {
  name                          = local.names.cosmos
  location                      = var.location
  resource_group_name           = var.resource_group_name
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  local_authentication_enabled  = false
  public_network_access_enabled = false
  minimal_tls_version           = "Tls12"
  tags                          = var.tags

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }
}

resource "azurerm_cosmosdb_sql_database" "this" {
  name                = local.names.cosmos_db
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
}

resource "azurerm_cosmosdb_sql_container" "conversations" {
  name                = "conversations"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this.name
  partition_key_paths = ["/id"]
  default_ttl         = 86400

  autoscale_settings {
    max_throughput = var.cosmos_autoscale_max_throughput
  }
}

resource "azurerm_cosmosdb_sql_container" "datasources" {
  name                = "datasources"
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.this.name
  partition_key_paths = ["/id"]

  autoscale_settings {
    max_throughput = var.cosmos_autoscale_max_throughput
  }

  indexing_policy {
    indexing_mode = "none"
  }
}

#------------------------------------------------------------------------------
# Azure AI Search (Entra-only, private).
#------------------------------------------------------------------------------
resource "azurerm_search_service" "this" {
  name                          = local.names.search
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = var.search_sku
  replica_count                 = var.search_replica_count
  partition_count               = var.search_partition_count
  semantic_search_sku           = var.search_semantic_sku
  local_authentication_enabled  = false
  public_network_access_enabled = false
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

#------------------------------------------------------------------------------
# Azure AI Services: chat + embedding models and Document Intelligence in one
# account. Keys disabled; reached privately from the spoke VNet.
#------------------------------------------------------------------------------
resource "azurerm_cognitive_account" "ai" {
  name                          = local.names.ai_services
  location                      = var.ai_location
  resource_group_name           = var.resource_group_name
  kind                          = "AIServices"
  sku_name                      = var.ai_services_sku
  custom_subdomain_name         = local.names.ai_services
  local_auth_enabled            = false
  public_network_access_enabled = false
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = var.embedding_deployment.name
  cognitive_account_id = azurerm_cognitive_account.ai.id

  model {
    format  = "OpenAI"
    name    = var.embedding_deployment.model_name
    version = var.embedding_deployment.model_version
  }

  sku {
    name     = var.embedding_deployment.sku_name
    capacity = var.embedding_deployment.capacity
  }
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = var.chat_deployment.name
  cognitive_account_id = azurerm_cognitive_account.ai.id

  model {
    format  = "OpenAI"
    name    = var.chat_deployment.model_name
    version = var.chat_deployment.model_version
  }

  sku {
    name     = var.chat_deployment.sku_name
    capacity = var.chat_deployment.capacity
  }

  # One deployment at a time: the account rejects parallel deployment changes.
  depends_on = [azurerm_cognitive_deployment.embedding]
}
