# Authentication comes from the environment: HCP Terraform dynamic credentials
# (OIDC) or `az login` locally. ARM_SUBSCRIPTION_ID selects the subscription.
provider "azurerm" {
  storage_use_azuread = true

  # azurerm 5.x registers nothing by default; register only what this needs.
  resource_providers_to_register = [
    "Microsoft.AlertsManagement",
    "Microsoft.CognitiveServices",
    "Microsoft.Compute",
    "Microsoft.Consumption",
    "Microsoft.DevTestLab",
    "Microsoft.DocumentDB",
    "Microsoft.Insights",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
    "Microsoft.PolicyInsights",
    "Microsoft.Search",
    "Microsoft.ServiceBus",
    "Microsoft.Sql",
    "Microsoft.Storage",
    "Microsoft.Web",
  ]

  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    cognitive_account {
      purge_soft_delete_on_destroy = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}
