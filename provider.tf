terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.96"
    }
  }
}

provider "azurerm" {
  features {}
}

# For tenant ID etc.
data "azurerm_client_config" "current" {}
