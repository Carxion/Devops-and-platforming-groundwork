terraform {
  required_version = "~> 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  # This stack creates the state storage, so it starts with local state.
  # After the first apply, uncomment this block, fill it in from the
  # `backend_config` output, and run `terraform init -migrate-state`.
  #
  # backend "azurerm" {
  #   resource_group_name  = "<resource_group_name>"
  #   storage_account_name = "<storage_account_name>"
  #   container_name       = "tfstate"
  #   key                  = "bootstrap-state/terraform.tfstate"
  #   use_azuread_auth     = true
  # }
}

provider "azurerm" {
  features {}
  subscription_id     = var.subscription_id
  storage_use_azuread = true # shared keys are disabled on the account
}
