terraform {
  required_version = ">= 1.7.0"

  required_providers {
    # AWS provider for CI runners infrastructure
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # TODO: Uncomment additional providers as needed
    # azurerm = {
    #   source  = "hashicorp/azurerm"
    #   version = "~> 3.0"
    # }
    # google = {
    #   source  = "hashicorp/google"
    #   version = "~> 4.0"
    # }
  }
}

# AWS provider configuration for CI runners
provider "aws" {
  region = var.aws_region
}

# TODO: Configure additional provider blocks based on your cloud platform
# provider "azurerm" {
#   features {}
# }

# provider "google" {
#   project = var.gcp_project_id
#   region  = var.gcp_region
# }