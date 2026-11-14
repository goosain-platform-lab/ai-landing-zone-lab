# Least-privilege RBAC for each system-assigned identity, in place of keys and
# connection strings.
locals {
  principals = {
    web    = azurerm_linux_web_app.frontend.identity[0].principal_id
    orch   = azurerm_linux_function_app.orchestrator.identity[0].principal_id
    ing    = azurerm_linux_function_app.ingestion.identity[0].principal_id
    search = azurerm_search_service.this.identity[0].principal_id
  }

  docs = azurerm_storage_account.this["docs"].id

  rbac = {
    # Front end
    web_docs = { who = "web", scope = local.docs, role = "Storage Blob Data Reader" }
    web_ai   = { who = "web", scope = azurerm_cognitive_account.ai.id, role = "Cognitive Services User" }
    web_kv   = { who = "web", scope = azurerm_key_vault.this.id, role = "Key Vault Secrets User" }
    web_appi = { who = "web", scope = azurerm_application_insights.this.id, role = "Monitoring Metrics Publisher" }

    # Orchestrator
    orch_docs   = { who = "orch", scope = local.docs, role = "Storage Blob Data Reader" }
    orch_openai = { who = "orch", scope = azurerm_cognitive_account.ai.id, role = "Cognitive Services OpenAI User" }
    orch_search = { who = "orch", scope = azurerm_search_service.this.id, role = "Search Index Data Reader" }
    orch_kv     = { who = "orch", scope = azurerm_key_vault.this.id, role = "Key Vault Secrets User" }
    orch_appi   = { who = "orch", scope = azurerm_application_insights.this.id, role = "Monitoring Metrics Publisher" }
    orch_host_b = { who = "orch", scope = azurerm_storage_account.this["orch"].id, role = "Storage Blob Data Owner" }
    orch_host_q = { who = "orch", scope = azurerm_storage_account.this["orch"].id, role = "Storage Queue Data Contributor" }
    orch_host_t = { who = "orch", scope = azurerm_storage_account.this["orch"].id, role = "Storage Table Data Contributor" }

    # Ingestion
    ing_docs       = { who = "ing", scope = local.docs, role = "Storage Blob Data Contributor" }
    ing_openai     = { who = "ing", scope = azurerm_cognitive_account.ai.id, role = "Cognitive Services OpenAI User" }
    ing_docintel   = { who = "ing", scope = azurerm_cognitive_account.ai.id, role = "Cognitive Services User" }
    ing_search     = { who = "ing", scope = azurerm_search_service.this.id, role = "Search Index Data Contributor" }
    ing_search_svc = { who = "ing", scope = azurerm_search_service.this.id, role = "Search Service Contributor" }
    ing_kv         = { who = "ing", scope = azurerm_key_vault.this.id, role = "Key Vault Secrets User" }
    ing_appi       = { who = "ing", scope = azurerm_application_insights.this.id, role = "Monitoring Metrics Publisher" }
    ing_host_b     = { who = "ing", scope = azurerm_storage_account.this["ing"].id, role = "Storage Blob Data Owner" }
    ing_host_q     = { who = "ing", scope = azurerm_storage_account.this["ing"].id, role = "Storage Queue Data Contributor" }
    ing_host_t     = { who = "ing", scope = azurerm_storage_account.this["ing"].id, role = "Storage Table Data Contributor" }

    # Search service identity (indexers and integrated vectorisation)
    search_docs   = { who = "search", scope = local.docs, role = "Storage Blob Data Reader" }
    search_openai = { who = "search", scope = azurerm_cognitive_account.ai.id, role = "Cognitive Services OpenAI User" }
  }
}

resource "azurerm_role_assignment" "this" {
  for_each = local.rbac

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = local.principals[each.value.who]
  principal_type       = "ServicePrincipal"
}

# Cosmos DB data-plane RBAC (built-in "Cosmos DB Built-in Data Contributor").
resource "azurerm_cosmosdb_sql_role_assignment" "orchestrator" {
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  role_definition_id  = "${azurerm_cosmosdb_account.this.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = local.principals.orch
  scope               = azurerm_cosmosdb_account.this.id
}
