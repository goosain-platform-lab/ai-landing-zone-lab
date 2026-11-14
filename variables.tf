#------------------------------------------------------------------------------
# Placement and naming
#------------------------------------------------------------------------------
variable "location" {
  description = "Primary region for the landing zone."
  type        = string
  default     = "southafricanorth"
}

variable "environment" {
  description = "Environment token used in every name: <type>-<workload>-<environment>-<region>."
  type        = string
  default     = "lab"
}

variable "unique_suffix" {
  description = "Optional 0-4 character suffix for globally unique names."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Extra tags merged onto the defaults."
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Connectivity
#------------------------------------------------------------------------------
variable "address_space" {
  description = "Spoke VNet address space (a /24 is carved into five subnets)."
  type        = string
  default     = "10.20.0.0/24"

  validation {
    condition     = tonumber(split("/", var.address_space)[1]) <= 24
    error_message = "address_space must be a /24 or larger."
  }
}

variable "hub_virtual_network_id" {
  description = "Optional hub VNet to peer with. The spoke side is created here; the hub owner creates the return peering."
  type        = string
  default     = null
}

variable "use_hub_gateway" {
  description = "Use the hub's VPN/ExpressRoute gateway for on-premises routes."
  type        = bool
  default     = false
}

variable "existing_private_dns_zone_ids" {
  description = "Private DNS zones that already exist in a hub, keyed like local.private_dns_zones (for example { blob = \"/subscriptions/.../privatelink.blob.core.windows.net\" }). Any zone not listed is created in the spoke."
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Management
#------------------------------------------------------------------------------
variable "log_retention_days" {
  description = "Log Analytics retention."
  type        = number
  default     = 30
}

variable "log_daily_quota_gb" {
  description = "Daily ingestion cap in GB (-1 for no cap)."
  type        = number
  default     = 1
}

variable "bastion_enabled" {
  description = "Deploy Azure Bastion for private access to the jumpbox."
  type        = bool
  default     = true
}

variable "bastion_sku" {
  description = "Bastion SKU (Standard supports native-client tunnelling)."
  type        = string
  default     = "Standard"
}

variable "jumpbox_enabled" {
  description = "Deploy a Windows jumpbox inside the VNet to reach the private apps."
  type        = bool
  default     = true
}

variable "jumpbox_size" {
  description = "Jumpbox VM size."
  type        = string
  default     = "Standard_D4s_v3"
}

variable "jumpbox_admin_principal_id" {
  description = "Object ID of the Entra group or user allowed to sign in to the jumpbox (Virtual Machine Administrator Login)."
  type        = string
  default     = null
}

variable "jumpbox_auto_shutdown_time" {
  description = "Daily shutdown time (HHMM, South Africa Standard Time). Null disables auto-shutdown."
  type        = string
  default     = "1900"
}

#------------------------------------------------------------------------------
# Governance
#------------------------------------------------------------------------------
variable "policy_guardrails_enabled" {
  description = "Assign the landing-zone guardrail policies at subscription scope."
  type        = bool
  default     = true
}

variable "policy_effect" {
  description = "Effect for the guardrail policies: Audit reports, Deny blocks."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.policy_effect)
    error_message = "policy_effect must be Audit, Deny or Disabled."
  }
}

variable "budget_amount" {
  description = "Monthly subscription budget in the billing currency. 0 disables the budget."
  type        = number
  default     = 0
}

variable "budget_contact_emails" {
  description = "Who receives budget alerts."
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Workloads
#------------------------------------------------------------------------------
variable "rag_enabled" {
  description = "Deploy the RAG chatbot workload."
  type        = bool
  default     = true
}

variable "stt_enabled" {
  description = "Deploy the speech-to-text workload."
  type        = bool
  default     = true
}

variable "ai_location" {
  description = "Region for the RAG model account (model availability drives this)."
  type        = string
  default     = "swedencentral"
}

variable "rag_search_sku" {
  description = "Azure AI Search SKU for RAG."
  type        = string
  default     = "standard2"
}

variable "rag_app_service_plan_sku" {
  description = "Linux plan SKU for the RAG apps."
  type        = string
  default     = "P1v3"
}

variable "rag_frontend_public_network_access_enabled" {
  description = "Expose the RAG chat front end publicly (off = reach it from the jumpbox)."
  type        = bool
  default     = false
}

variable "stt_batch_enabled" {
  description = "Deploy the STT batch pipeline (Function App, Service Bus, SQL, Azure OpenAI)."
  type        = bool
  default     = true
}

variable "stt_service_bus_sku" {
  description = "Service Bus SKU for the STT batch pipeline (Premium = private endpoint)."
  type        = string
  default     = "Premium"
}

variable "stt_app_service_plan_sku" {
  description = "Windows plan SKU shared by the STT apps and the batch Function App."
  type        = string
  default     = "B1"
}

variable "stt_openai_deployments" {
  description = "Model deployments for STT batch summarisation."
  type = map(object({
    model_name    = string
    model_version = string
    sku_name      = optional(string, "GlobalStandard")
    capacity      = optional(number, 10)
  }))
  default = {}
}

variable "sql_entra_admin" {
  description = "Entra group (recommended) that administers the STT batch SQL server. Null uses the deploying identity."
  type = object({
    login_username = string
    object_id      = string
  })
  default = null
}
