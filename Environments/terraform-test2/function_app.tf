
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.75"
    }
  }

  required_version = ">= 1.0.0"
}

provider "azurerm" {
  features {}

  skip_provider_registration = true
}

variable "location" {
  description = "The supported Azure location where the resource deployed"
  type        = string
}

variable "environment_name" {
  description = "The name of the azd environment to be deployed"
  type        = string
}

module "key_vault" {
  source = "github.com/Azure/azure-data-labs-modules/terraform/key-vault"

  basename                 = "senyangtestkv"
  resource_group_name      = var.environment_name
  location                 = var.location
  sku_name                 = "premium"
  purge_protection_enabled = false

  subnet_id            = null
  private_dns_zone_ids = null

  is_private_endpoint = false

  tags = {
    Owner       = "Azure Data Labs"
    Project     = "Azure Data Labs"
    Environment = "dev"
  }
}