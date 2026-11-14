locals {
  private_endpoints = {
    kv = {
      resource_id = azurerm_key_vault.this.id
      subresource = "vault"
      dns_zones   = ["vault"]
    }
    st-docs-blob = {
      resource_id = azurerm_storage_account.this["docs"].id
      subresource = "blob"
      dns_zones   = ["blob"]
    }
    st-orch-blob = {
      resource_id = azurerm_storage_account.this["orch"].id
      subresource = "blob"
      dns_zones   = ["blob"]
    }
    st-orch-queue = {
      resource_id = azurerm_storage_account.this["orch"].id
      subresource = "queue"
      dns_zones   = ["queue"]
    }
    st-orch-table = {
      resource_id = azurerm_storage_account.this["orch"].id
      subresource = "table"
      dns_zones   = ["table"]
    }
    st-ing-blob = {
      resource_id = azurerm_storage_account.this["ing"].id
      subresource = "blob"
      dns_zones   = ["blob"]
    }
    st-ing-queue = {
      resource_id = azurerm_storage_account.this["ing"].id
      subresource = "queue"
      dns_zones   = ["queue"]
    }
    st-ing-table = {
      resource_id = azurerm_storage_account.this["ing"].id
      subresource = "table"
      dns_zones   = ["table"]
    }
    cosmos = {
      resource_id = azurerm_cosmosdb_account.this.id
      subresource = "Sql"
      dns_zones   = ["cosmos"]
    }
    search = {
      resource_id = azurerm_search_service.this.id
      subresource = "searchService"
      dns_zones   = ["search"]
    }
    # An AI Services account answers on three host names, so its endpoint
    # registers in three zones.
    ai = {
      resource_id = azurerm_cognitive_account.ai.id
      subresource = "account"
      dns_zones   = ["cognitive", "openai", "aiservices"]
    }
    web = {
      resource_id = azurerm_linux_web_app.frontend.id
      subresource = "sites"
      dns_zones   = ["sites"]
    }
    orch = {
      resource_id = azurerm_linux_function_app.orchestrator.id
      subresource = "sites"
      dns_zones   = ["sites"]
    }
    ing = {
      resource_id = azurerm_linux_function_app.ingestion.id
      subresource = "sites"
      dns_zones   = ["sites"]
    }
  }
}

resource "azurerm_private_endpoint" "this" {
  for_each = local.private_endpoints

  name                          = "pe-${each.key}-${local.base}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  subnet_id                     = var.private_endpoint_subnet_id
  custom_network_interface_name = "nic-pe-${each.key}-${local.base}"
  tags                          = var.tags

  private_service_connection {
    name                           = "psc-${each.key}-${local.base}"
    private_connection_resource_id = each.value.resource_id
    subresource_names              = [each.value.subresource]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [for z in each.value.dns_zones : var.private_dns_zone_ids[z]]
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = {
    key_vault    = azurerm_key_vault.this.id
    cosmos       = azurerm_cosmosdb_account.this.id
    search       = azurerm_search_service.this.id
    ai_services  = azurerm_cognitive_account.ai.id
    frontend     = azurerm_linux_web_app.frontend.id
    orchestrator = azurerm_linux_function_app.orchestrator.id
    ingestion    = azurerm_linux_function_app.ingestion.id
  }

  name                       = "diag-to-law"
  target_resource_id         = each.value
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}
