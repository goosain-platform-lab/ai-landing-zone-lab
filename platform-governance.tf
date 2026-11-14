# Landing-zone guardrails: built-in Azure Policy definitions assigned at
# subscription scope. Default effect is Audit (report only); set
# policy_effect = "Deny" to enforce. IDs are the built-in definition names.
locals {
  allowed_locations = distinct([var.location, var.ai_location])

  guardrail_policies = {
    allowed-locations = {
      id           = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
      display_name = "Allowed locations"
      parameters   = { listOfAllowedLocations = { value = local.allowed_locations } }
    }
    storage-no-shared-key = {
      id           = "8c6a50c6-9ffd-4ae7-986f-5fa6111f9a54"
      display_name = "Storage accounts should prevent shared key access"
      parameters   = {}
    }
    storage-no-public = {
      id           = "b2982f36-99f2-4db5-8eff-283140c09693"
      display_name = "Storage accounts should disable public network access"
      parameters   = {}
    }
    ai-no-local-auth = {
      id           = "71ef260a-8f18-47b7-abcb-62d0673d94dc"
      display_name = "Azure AI Services resources should have key access disabled"
      parameters   = {}
    }
    ai-restrict-network = {
      id           = "037eea7a-bd0a-46c5-9a66-03aea78705d3"
      display_name = "Azure AI Services resources should restrict network access"
      parameters   = {}
    }
    kv-rbac = {
      id           = "12d4fa5e-1f9f-4c21-97a9-b99b3c6611b5"
      display_name = "Azure Key Vault should use RBAC permission model"
      parameters   = {}
    }
    kv-no-public = {
      id           = "405c5871-3e91-4644-8a63-58e19d68ff5b"
      display_name = "Azure Key Vault should disable public network access"
      parameters   = {}
    }
    servicebus-no-local-auth = {
      id           = "cfb11c26-f069-4c14-8e36-56c394dae5af"
      display_name = "Azure Service Bus namespaces should have local authentication methods disabled"
      parameters   = {}
    }
    appservice-https = {
      id           = "a4af4a39-4135-47fb-b175-47fbdf85311d"
      display_name = "App Service apps should only be accessible over HTTPS"
      parameters   = {}
    }
    function-https = {
      id           = "6d555dd1-86f2-4f1c-8ed7-5abae7c6cbab"
      display_name = "Function apps should only be accessible over HTTPS"
      parameters   = {}
    }
    aks-private = {
      id           = "040732e8-d947-40b8-95d6-854c95024bf8"
      display_name = "Azure Kubernetes Service Private Clusters should be enabled"
      parameters   = {}
    }
    aks-no-local-auth = {
      id           = "993c2fcd-2b29-49d2-9eb0-df2c3a730c32"
      display_name = "Azure Kubernetes Service Clusters should have local authentication methods disabled"
      parameters   = {}
    }
    # Enforced inside the cluster by the Azure Policy add-on (Gatekeeper).
    k8s-no-privilege-escalation = {
      id           = "1c6e92c9-99f0-4e55-9cf2-0c234dc48f99"
      display_name = "Kubernetes clusters should not allow container privilege escalation"
      parameters   = {}
    }
  }

  # Definitions that only support Audit: they stay on Audit when Deny is chosen.
  audit_only_policies = ["aks-private", "aks-no-local-auth"]
}

resource "azurerm_subscription_policy_assignment" "guardrails" {
  for_each = var.policy_guardrails_enabled ? local.guardrail_policies : {}

  name                 = "ailz-${each.key}"
  display_name         = "AI LZ (${var.environment}): ${each.value.display_name}"
  subscription_id      = data.azurerm_subscription.current.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${each.value.id}"
  parameters = jsonencode(merge(each.value.parameters, {
    effect = { value = contains(local.audit_only_policies, each.key) && var.policy_effect == "Deny" ? "Audit" : var.policy_effect }
  }))
}

#------------------------------------------------------------------------------
# Cost guardrail: monthly budget with actual and forecast alerts.
#------------------------------------------------------------------------------
resource "azurerm_consumption_budget_subscription" "this" {
  count = var.budget_amount > 0 && length(var.budget_contact_emails) > 0 ? 1 : 0

  name            = "budget-ai-${local.suffix}"
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", plantimestamp())
  }

  notification {
    enabled        = true
    operator       = "GreaterThan"
    threshold      = 80
    threshold_type = "Actual"
    contact_emails = var.budget_contact_emails
  }

  notification {
    enabled        = true
    operator       = "GreaterThan"
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = var.budget_contact_emails
  }

  lifecycle {
    # The start date is fixed at first apply.
    ignore_changes = [time_period]
  }
}
