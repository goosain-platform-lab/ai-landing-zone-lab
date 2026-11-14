data "azurerm_client_config" "current" {}

locals {
  region_codes = {
    southafricanorth   = "zan"
    southafricawest    = "zaw"
    westeurope         = "weu"
    northeurope        = "neu"
    swedencentral      = "sdc"
    uksouth            = "uks"
    francecentral      = "frc"
    germanywestcentral = "gwc"
    switzerlandnorth   = "szn"
    eastus             = "eus"
    eastus2            = "eus2"
  }

  region    = lookup(local.region_codes, var.location, var.location)
  ai_region = lookup(local.region_codes, var.ai_location, var.ai_location)

  # <type>-<workload>-<environment>-<region>[suffix]
  base    = "${var.workload}-${var.environment}-${local.region}${var.unique_suffix}"
  compact = "${var.workload}%s${var.environment}${local.region}${var.unique_suffix}"

  names = {
    key_vault    = "kv-${local.base}"
    app_insights = "appi-${local.base}"
    ai_services  = "ais-${var.workload}-${var.environment}-${local.ai_region}${var.unique_suffix}"
    search       = "srch-${local.base}"
    cosmos       = "cosmos-${local.base}"
    cosmos_db    = "db-${var.workload}"
    storage_docs = substr("st${format(local.compact, "docs")}", 0, 24)
    storage_orch = substr("st${format(local.compact, "orch")}", 0, 24)
    storage_ing  = substr("st${format(local.compact, "ing")}", 0, 24)
    plan         = "asp-${local.base}"
    frontend     = "app-${var.workload}-web-${var.environment}-${local.region}${var.unique_suffix}"
    orchestrator = "func-${var.workload}-orch-${var.environment}-${local.region}${var.unique_suffix}"
    ingestion    = "func-${var.workload}-ing-${var.environment}-${local.region}${var.unique_suffix}"
  }

  docs_container        = "documents"
  docs_images_container = "documents-images"
}
