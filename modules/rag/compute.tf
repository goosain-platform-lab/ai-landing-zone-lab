# Linux plan shared by the chat front end and the two Function Apps. Each app
# has a system-assigned identity; all access to data and models is RBAC on
# that identity.
resource "azurerm_service_plan" "this" {
  name                = local.names.plan
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                         = local.names.app_insights
  location                     = var.location
  resource_group_name          = var.resource_group_name
  application_type             = "web"
  workspace_id                 = var.log_analytics_workspace_id
  local_authentication_enabled = false
  tags                         = var.tags
}

locals {
  common_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING     = azurerm_application_insights.this.connection_string
    APPLICATIONINSIGHTS_AUTHENTICATION_STRING = "Authorization=AAD"
    AZURE_KEY_VAULT_NAME                      = azurerm_key_vault.this.name
    AZURE_KEY_VAULT_ENDPOINT                  = azurerm_key_vault.this.vault_uri
    SCM_DO_BUILD_DURING_DEPLOYMENT            = "true"
    ENABLE_ORYX_BUILD                         = "true"
  }

  ai_settings = {
    AZURE_OPENAI_RESOURCE             = azurerm_cognitive_account.ai.name
    AZURE_OPENAI_SERVICE_NAME         = azurerm_cognitive_account.ai.name
    AZURE_OPENAI_ENDPOINT             = azurerm_cognitive_account.ai.endpoint
    AZURE_OPENAI_CHATGPT_DEPLOYMENT   = azurerm_cognitive_deployment.chat.name
    AZURE_OPENAI_CHATGPT_MODEL        = var.chat_deployment.model_name
    AZURE_OPENAI_EMBEDDING_DEPLOYMENT = azurerm_cognitive_deployment.embedding.name
    AZURE_OPENAI_EMBEDDING_MODEL      = var.embedding_deployment.model_name
    AZURE_EMBEDDINGS_VECTOR_SIZE      = tostring(var.embedding_deployment.dimensions)
    AZURE_SEARCH_SERVICE              = azurerm_search_service.this.name
    AZURE_SEARCH_INDEX                = var.search_index_name
    AZURE_SEARCH_USE_SEMANTIC         = var.search_semantic_sku == null ? "false" : "true"
    STORAGE_ACCOUNT                   = azurerm_storage_account.this["docs"].name
    STORAGE_CONTAINER                 = local.docs_container
    STORAGE_CONTAINER_IMAGES          = local.docs_images_container
    NETWORK_ISOLATION                 = "true"
  }

  frontend_kv_settings = {
    for setting, secret in var.frontend_key_vault_references :
    setting => "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.this.name};SecretName=${secret})"
  }
}

#------------------------------------------------------------------------------
# Chat front end (placeholder app: deploy your own code to it)
#------------------------------------------------------------------------------
resource "azurerm_linux_web_app" "frontend" {
  name                                           = local.names.frontend
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.this.id
  https_only                                     = true
  public_network_access_enabled                  = var.frontend_public_network_access_enabled
  virtual_network_subnet_id                      = var.app_subnet_id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  tags                                           = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    vnet_route_all_enabled = true
    minimum_tls_version    = "1.2"
    ftps_state             = "Disabled"

    application_stack {
      python_version = var.frontend_python_version
    }
  }

  app_settings = merge(local.common_settings, local.frontend_kv_settings, {
    ORCHESTRATOR_ENDPOINT = "https://${azurerm_linux_function_app.orchestrator.default_hostname}/api/orc"
    AI_SERVICES_ENDPOINT  = azurerm_cognitive_account.ai.endpoint
    SPEECH_REGION         = var.ai_location
    STORAGE_ACCOUNT       = azurerm_storage_account.this["docs"].name
    STORAGE_CONTAINER     = local.docs_container
  })
}

#------------------------------------------------------------------------------
# Orchestrator Function App
#------------------------------------------------------------------------------
resource "azurerm_linux_function_app" "orchestrator" {
  name                                           = local.names.orchestrator
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.this.id
  https_only                                     = true
  public_network_access_enabled                  = false
  virtual_network_subnet_id                      = var.app_subnet_id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  functions_extension_version                    = "~4"
  storage_account_name                           = azurerm_storage_account.this["orch"].name
  storage_uses_managed_identity                  = true
  tags                                           = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    vnet_route_all_enabled = true
    minimum_tls_version    = "1.2"
    ftps_state             = "Disabled"

    application_stack {
      python_version = var.functions_python_version
    }
  }

  app_settings = merge(local.common_settings, local.ai_settings, {
    AZURE_DB_ID                           = azurerm_cosmosdb_account.this.name
    AZURE_DB_NAME                         = azurerm_cosmosdb_sql_database.this.name
    AZURE_DB_CONVERSATIONS_CONTAINER_NAME = azurerm_cosmosdb_sql_container.conversations.name
    AZURE_DB_DATASOURCES_CONTAINER_NAME   = azurerm_cosmosdb_sql_container.datasources.name
  })
}

#------------------------------------------------------------------------------
# Ingestion Function App (chunks documents, embeds them, writes the index)
#------------------------------------------------------------------------------
resource "azurerm_linux_function_app" "ingestion" {
  name                                           = local.names.ingestion
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.this.id
  https_only                                     = true
  public_network_access_enabled                  = false
  virtual_network_subnet_id                      = var.app_subnet_id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  functions_extension_version                    = "~4"
  storage_account_name                           = azurerm_storage_account.this["ing"].name
  storage_uses_managed_identity                  = true
  tags                                           = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on              = true
    vnet_route_all_enabled = true
    minimum_tls_version    = "1.2"
    ftps_state             = "Disabled"

    application_stack {
      python_version = var.functions_python_version
    }
  }

  app_settings = merge(local.common_settings, local.ai_settings, {
    AZURE_FORMREC_SERVICE = azurerm_cognitive_account.ai.name
    SEARCH_INDEX_NAME     = var.search_index_name
    STORAGE_ACCOUNT_NAME  = azurerm_storage_account.this["docs"].name
  })
}
