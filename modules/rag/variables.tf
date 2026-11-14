#------------------------------------------------------------------------------
# Naming and placement
#------------------------------------------------------------------------------
variable "workload" {
  description = "Workload token used in resource names."
  type        = string
  default     = "rag"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.workload))
    error_message = "workload must be 2-8 lowercase letters or digits."
  }
}

variable "environment" {
  description = "Environment token used in resource names."
  type        = string
  default     = "lab"
}

variable "location" {
  description = "Region for the apps, data and search."
  type        = string
}

variable "unique_suffix" {
  description = "Optional 0-4 character suffix for globally unique names."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]{0,4}$", var.unique_suffix))
    error_message = "unique_suffix must be 0-4 lowercase letters or digits."
  }
}

variable "resource_group_name" {
  description = "Existing resource group for the workload."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Network wiring
#------------------------------------------------------------------------------
variable "app_subnet_id" {
  description = "Subnet delegated to Microsoft.Web/serverFarms for VNet integration."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet for private endpoints."
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Private DNS zone IDs keyed by: blob, queue, table, vault, cognitive, openai, aiservices, search, cosmos, sites."
  type        = map(string)

  validation {
    condition = alltrue([
      for k in ["blob", "queue", "table", "vault", "cognitive", "openai", "aiservices", "search", "cosmos", "sites"] :
      contains(keys(var.private_dns_zone_ids), k)
    ])
    error_message = "private_dns_zone_ids is missing one of: blob, queue, table, vault, cognitive, openai, aiservices, search, cosmos, sites."
  }
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace for diagnostics and Application Insights."
  type        = string
}

#------------------------------------------------------------------------------
# AI (defaults are production-grade SKUs)
#------------------------------------------------------------------------------
variable "ai_location" {
  description = "Region for the Azure AI Services account (model availability drives this)."
  type        = string
  default     = "swedencentral"
}

variable "ai_services_sku" {
  description = "SKU for the Azure AI Services account."
  type        = string
  default     = "S0"
}

variable "chat_deployment" {
  description = "Chat model deployment used by the orchestrator."
  type = object({
    name          = string
    model_name    = string
    model_version = string
    sku_name      = string
    capacity      = number
  })
  default = {
    name          = "chat"
    model_name    = "gpt-5.1"
    model_version = "2025-11-13"
    sku_name      = "GlobalStandard"
    capacity      = 40
  }
}

variable "embedding_deployment" {
  description = "Embedding model deployment used for indexing and retrieval."
  type = object({
    name          = string
    model_name    = string
    model_version = string
    sku_name      = string
    capacity      = number
    dimensions    = number
  })
  default = {
    name          = "text-embedding"
    model_name    = "text-embedding-3-large"
    model_version = "1"
    sku_name      = "Standard"
    capacity      = 40
    dimensions    = 3072
  }
}

variable "search_sku" {
  description = "Azure AI Search SKU."
  type        = string
  default     = "standard2"
}

variable "search_replica_count" {
  description = "Search replicas."
  type        = number
  default     = 1
}

variable "search_partition_count" {
  description = "Search partitions."
  type        = number
  default     = 1
}

variable "search_semantic_sku" {
  description = "Semantic ranker plan (free or standard). Null disables it."
  type        = string
  default     = "free"
}

variable "search_index_name" {
  description = "Index name the apps are told to use (the ingestion app creates it)."
  type        = string
  default     = "ragindex"
}

#------------------------------------------------------------------------------
# Data and compute
#------------------------------------------------------------------------------
variable "cosmos_autoscale_max_throughput" {
  description = "Autoscale maximum RU/s per Cosmos container."
  type        = number
  default     = 1000
}

variable "storage_replication_type" {
  description = "Replication for the storage accounts."
  type        = string
  default     = "LRS"
}

variable "app_service_plan_sku" {
  description = "Linux plan SKU shared by the front end and both Function Apps."
  type        = string
  default     = "P1v3"
}

variable "frontend_python_version" {
  description = "Python version for the front-end web app."
  type        = string
  default     = "3.12"
}

variable "functions_python_version" {
  description = "Python version for the orchestrator and ingestion Function Apps."
  type        = string
  default     = "3.11"
}

variable "frontend_public_network_access_enabled" {
  description = "Expose the chat front end publicly. Off by default (zero-trust): browse it from the jumpbox."
  type        = bool
  default     = false
}

variable "frontend_key_vault_references" {
  description = "Front-end app setting => Key Vault secret name. The orchestrator's function key is the one secret this pattern still needs."
  type        = map(string)
  default = {
    ORCHESTRATOR_FUNCTION_KEY = "orchestrator-function-key"
  }
}

variable "key_vault_purge_protection_enabled" {
  description = "Key Vault purge protection (off for the lab so redeploys can reuse the name)."
  type        = bool
  default     = false
}
