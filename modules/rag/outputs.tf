output "key_vault" {
  description = "Key Vault name and URI."
  value = {
    id   = azurerm_key_vault.this.id
    name = azurerm_key_vault.this.name
    uri  = azurerm_key_vault.this.vault_uri
  }
}

output "apps" {
  description = "App names and host names."
  value = {
    frontend_name     = azurerm_linux_web_app.frontend.name
    frontend_hostname = azurerm_linux_web_app.frontend.default_hostname
    orchestrator_name = azurerm_linux_function_app.orchestrator.name
    ingestion_name    = azurerm_linux_function_app.ingestion.name
  }
}

output "endpoints" {
  description = "Service endpoints (not secrets)."
  value = {
    ai_services = azurerm_cognitive_account.ai.endpoint
    search      = "https://${azurerm_search_service.this.name}.search.windows.net"
    cosmos      = azurerm_cosmosdb_account.this.endpoint
    docs_blob   = azurerm_storage_account.this["docs"].primary_blob_endpoint
  }
}

output "search_principal_id" {
  description = "Search service identity, for shared private links if you add indexers."
  value       = azurerm_search_service.this.identity[0].principal_id
}
