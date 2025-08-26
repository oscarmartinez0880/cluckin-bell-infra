terraform {
  required_version = ">= 1.7.0"

  required_providers {
    # TODO: Uncomment and configure providers based on your cloud platform
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "~> 5.0"
    # }
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

# TODO: Configure provider blocks based on your cloud platform
# provider "aws" {
#   region = var.aws_region
# }

# provider "azurerm" {
#   features {}
# }

# provider "google" {
#   project = var.gcp_project_id
#   region  = var.gcp_region
# }