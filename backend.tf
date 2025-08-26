# TODO: Configure remote backend for production use
# This is currently set to local backend for development
# Uncomment and configure one of the remote backend options below

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  # AWS S3 + DynamoDB backend example:
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "infra/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-state-lock"
  #   encrypt        = true
  # }

  # Google Cloud Storage backend example:
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "infra"
  # }

  # Azure Storage backend example:
  # backend "azurerm" {
  #   resource_group_name  = "your-rg"
  #   storage_account_name = "yourstorageaccount"
  #   container_name       = "terraform-state"
  #   key                  = "infra.terraform.tfstate"
  # }
}