terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.14"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }

  # HCP Terraform. Organization and workspace come from TF_CLOUD_ORGANIZATION
  # and TF_WORKSPACE so nothing tenant-specific is committed. Delete this block
  # for a local-state run.
  cloud {}
}
