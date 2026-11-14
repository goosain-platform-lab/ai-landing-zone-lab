data "azurerm_subscription" "current" {}

locals {
  region = lookup({
    southafricanorth = "zan"
    southafricawest  = "zaw"
    westeurope       = "weu"
    northeurope      = "neu"
    swedencentral    = "sdc"
    uksouth          = "uks"
  }, var.location, var.location)

  # <type>-<workload>-<environment>-<region>[suffix]
  suffix = "${var.environment}-${local.region}${var.unique_suffix}"

  tags = merge({
    environment = var.environment
    managed_by  = "terraform"
    repo        = "ai-landing-zone-lab"
  }, var.tags)

  # Subnet plan for the /24 spoke:
  #   .0/26   AzureBastionSubnet
  #   .64/26  private endpoints (shared by all workloads)
  #   .128/27 RAG App Service integration
  #   .160/27 STT App Service integration
  #   .192/28 jumpbox
  subnets = {
    bastion = cidrsubnet(var.address_space, 2, 0)
    pe      = cidrsubnet(var.address_space, 2, 1)
    rag-app = cidrsubnet(var.address_space, 3, 4)
    stt-app = cidrsubnet(var.address_space, 3, 5)
    jumpbox = cidrsubnet(var.address_space, 4, 12)
  }

  private_dns_zones = {
    blob       = "privatelink.blob.core.windows.net"
    file       = "privatelink.file.core.windows.net"
    queue      = "privatelink.queue.core.windows.net"
    table      = "privatelink.table.core.windows.net"
    vault      = "privatelink.vaultcore.azure.net"
    cognitive  = "privatelink.cognitiveservices.azure.com"
    openai     = "privatelink.openai.azure.com"
    aiservices = "privatelink.services.ai.azure.com"
    search     = "privatelink.search.windows.net"
    cosmos     = "privatelink.documents.azure.com"
    sites      = "privatelink.azurewebsites.net"
    servicebus = "privatelink.servicebus.windows.net"
    sql        = "privatelink.database.windows.net"
  }
}
