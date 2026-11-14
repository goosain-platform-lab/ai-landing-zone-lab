output "resource_groups" {
  description = "Landing zone resource groups."
  value = {
    network = azurerm_resource_group.network.name
    shared  = azurerm_resource_group.shared.name
    rag     = var.rag_enabled ? azurerm_resource_group.rag[0].name : null
    stt     = var.stt_enabled ? azurerm_resource_group.stt[0].name : null
  }
}

output "network" {
  description = "Spoke VNet and subnets."
  value = {
    vnet_id   = azurerm_virtual_network.spoke.id
    vnet_name = azurerm_virtual_network.spoke.name
    subnets   = local.subnets
  }
}

output "log_analytics_workspace_id" {
  description = "Central workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "private_dns_zone_ids" {
  description = "Zone IDs used by the workloads (give these to the hub team if they host DNS)."
  value       = local.private_dns_zone_ids
}

output "jumpbox" {
  description = "Jumpbox name (sign in through Bastion with Entra ID)."
  value       = var.jumpbox_enabled ? azurerm_windows_virtual_machine.jumpbox[0].name : null
}

output "rag" {
  description = "RAG workload outputs."
  value = var.rag_enabled ? {
    key_vault = module.rag[0].key_vault
    apps      = module.rag[0].apps
    endpoints = module.rag[0].endpoints
  } : null
}

output "aks" {
  description = "AKS workload outputs."
  value = var.aks_enabled ? {
    cluster           = module.aks[0].cluster
    registry          = module.aks[0].registry
    workload_identity = module.aks[0].workload_identity
  } : null
}

output "stt" {
  description = "STT workload outputs (real-time and batch)."
  value = var.stt_enabled ? {
    identity  = module.stt[0].identity
    key_vault = module.stt[0].key_vault
    apps      = module.stt[0].apps
    endpoints = module.stt[0].endpoints
    batch = var.stt_batch_enabled ? {
      identity     = module.stt_batch[0].identity
      function_app = module.stt_batch[0].function_app
      service_bus  = module.stt_batch[0].service_bus
      sql          = module.stt_batch[0].sql
    } : null
  } : null
}
