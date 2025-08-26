# Cluckin Bell Infrastructure

This repository contains the Terraform infrastructure code for the Cluckin Bell project, supporting dev, qa, and prod environments with a vendor-neutral approach that can be configured for AWS, Azure, or GCP.

**New: Windows GitHub Actions CI Runners for Sitecore** - This repository now includes infrastructure for autoscaling Windows Server 2022 GitHub Actions runners specifically designed for Sitecore container builds on AWS.

## Directory Structure

```
.
├── modules/
│   └── ci-runners/          # Windows GitHub Actions runners module
├── docs/
│   ├── infra-ci.md         # Terraform CI/CD documentation
│   └── github-actions-runners.md  # CI runners usage guide
├── .github/workflows/      # GitHub Actions workflows
├── main.tf                 # Main infrastructure configuration
├── variables.tf            # Input variables
├── outputs.tf              # Output values
├── versions.tf             # Provider requirements
├── backend.tf              # Backend configuration
└── terraform.tfvars.example  # Example variables file
```

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

The repository is now configured for AWS by default to support the CI runners infrastructure. The AWS provider is enabled in `versions.tf` and configured to use the region specified in `variables.tf`.

**For AWS (Default):**
Already configured - no changes needed.

**For Azure:**
```hcl
# In versions.tf - uncomment azurerm provider
azurerm = {
  source  = "hashicorp/azurerm"
  version = "~> 3.0"
}

# In main.tf - add provider block
provider "azurerm" {
  features {}
}
```

**For GCP:**
```hcl
# In versions.tf - uncomment google provider
google = {
  source  = "hashicorp/google"
  version = "~> 4.0"
}

# In main.tf - add provider block
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

### 5. CI Runners Setup (Optional)

To enable Windows GitHub Actions runners for Sitecore builds:

1. **Copy and customize variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your configuration
   ```

2. **Set up GitHub App:**
   - Create a GitHub App with Actions:Read, Administration:Read, Metadata:Read permissions
   - Install the app on your organization/repositories
   - Store the private key in AWS SSM Parameter Store

3. **Configure variables in terraform.tfvars:**
   ```hcl
   enable_ci_runners = true
   ci_runners_github_app_id = "123456"
   ci_runners_github_app_installation_id = "789012"
   ci_runners_github_repository_allowlist = ["your-org/your-repo"]
   ```

4. **Apply infrastructure:**
   ```bash
   terraform apply
   ```

See [GitHub Actions Runners Documentation](docs/github-actions-runners.md) for detailed setup and usage instructions.

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
- **CI Runners Smoke Test**: Validates Windows runners for Sitecore container builds

### Windows GitHub Actions Runners

The infrastructure includes a dedicated module for autoscaling Windows Server 2022 GitHub Actions runners designed for Sitecore container builds:

- **Ephemeral runners**: Scale-from-zero with per-job instances
- **Windows containers**: Docker support for Windows container builds
- **ECR integration**: Built-in support for pushing to Amazon ECR via OIDC
- **Private networking**: Runners operate in private subnets behind NAT
- **Auto scaling**: Configurable min/max instances with optional webhook scaling

#### Usage in Workflows

Target the runners using these labels:
```yaml
runs-on: [self-hosted, windows, x64, windows-containers]
```

For detailed setup and usage instructions, see [GitHub Actions Runners Documentation](docs/github-actions-runners.md).

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