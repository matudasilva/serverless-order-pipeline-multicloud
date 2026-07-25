terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.67.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "2.10.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}
