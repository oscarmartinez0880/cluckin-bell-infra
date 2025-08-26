# Cluckin Bell Infrastructure

This repository contains the Terraform infrastructure code for the Cluckin Bell project, supporting dev, qa, and prod environments with a vendor-neutral approach that can be configured for AWS, Azure, or GCP.

## Directory Structure

```
.
├── main.tf              # Main infrastructure configuration
├── versions.tf          # Terraform and provider version constraints
├── variables.tf         # Input variables
├── outputs.tf          # Output values
├── backend.tf          # Backend configuration
├── Makefile            # Common Terraform operations
├── .terraform-version  # Terraform version specification
└── .gitignore         # Git ignore patterns for Terraform
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.7.0
- Cloud provider CLI tools (AWS CLI, Azure CLI, or gcloud) configured with appropriate credentials
- Access to the target cloud subscription/account

## Getting Started

### 1. Initialize Terraform

```bash
# Using Makefile
make init

# Or directly
terraform init
```

### 2. Configure Provider

Before planning or applying, uncomment and configure the appropriate provider in `versions.tf` and `main.tf`:

**For AWS:**
```hcl
# In versions.tf
aws = {
  source  = "hashicorp/aws"
  version = "~> 5.0"
}

# In main.tf
provider "aws" {
  region = var.aws_region
}
```

**For Azure:**
```hcl
# In versions.tf
azurerm = {
  source  = "hashicorp/azurerm"
  version = "~> 3.0"
}

# In main.tf
provider "azurerm" {
  features {}
}
```

**For GCP:**
```hcl
# In versions.tf
google = {
  source  = "hashicorp/google"
  version = "~> 4.0"
}

# In main.tf
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
```

### 3. Configure Backend

Update `backend.tf` to use a remote backend for production:

**S3 Backend (AWS):**
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Azure Storage Backend:**
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "your-rg"
    storage_account_name = "yourstorageaccount"
    container_name       = "terraform-state"
    key                  = "infra.terraform.tfstate"
  }
}
```

**GCS Backend (GCP):**
```hcl
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "infra"
  }
}
```

### 4. Plan and Apply

```bash
# Format and validate
make lint

# Generate plan
make plan

# Apply changes
make apply
```

## Available Make Targets

- `make help` - Show available targets
- `make init` - Initialize Terraform
- `make fmt` - Format Terraform files
- `make validate` - Validate configuration
- `make plan` - Generate execution plan
- `make apply` - Apply changes
- `make destroy` - Destroy infrastructure
- `make clean` - Clean temporary files
- `make ci` - Run CI pipeline (init, lint, plan)

## Environment Variables

Create a `.tfvars` file for your environment:

```hcl
# terraform.tfvars (example)
environment   = "dev"
project_name  = "cluckin-bell"

# Provider-specific variables
aws_region    = "us-east-1"  # For AWS
# azure_location = "East US"   # For Azure
# gcp_project_id = "my-project" # For GCP
```

## CI/CD

This repository includes GitHub Actions workflows for:

- **PR Checks**: Runs `terraform fmt`, `validate`, and `plan` on pull requests
- **Environment Deployments**: Separate workflows for dev, qa, and prod environments

### Required Secrets

Set the following repository secrets based on your cloud provider:

**AWS:**
- `AWS_TERRAFORM_ROLE_ARN`: IAM Role ARN for GitHub OIDC

**Azure:**
- `AZURE_CLIENT_ID`: Service Principal Client ID
- `AZURE_TENANT_ID`: Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID

**GCP:**
- `GCP_SA_KEY`: Service Account JSON key (base64 encoded)

## Contributing

1. Create a feature branch from `develop`
2. Make your changes
3. Run `make ci` to validate
4. Submit a pull request

## Security

- Never commit `.tfvars` files containing sensitive data
- Use remote backends with encryption
- Review security scanning results in GitHub Security tab
- Follow principle of least privilege for cloud IAM roles