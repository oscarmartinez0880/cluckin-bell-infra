# GitHub Actions IAM Roles

This document describes the IAM roles created for GitHub Actions to interact with AWS resources using OIDC authentication.

## Overview

The infrastructure creates specialized IAM roles that allow GitHub Actions workflows from the `oscarmartinez0880/cluckin-bell` repository to perform specific AWS operations without requiring long-lived credentials. All roles use GitHub OIDC (OpenID Connect) for secure, keyless authentication.

## Roles by Account

### Dev/QA Account (264765154707)

#### ECR Read Role: `GH_ECR_Read_cluckin_bell_app`
- **Purpose**: Read ECR tags and metadata for the `cluckin-bell-app` repository
- **Trust Policy**: Restricted to `repo:oscarmartinez0880/cluckin-bell:environment:qa`
- **Permissions**:
  - `ecr:DescribeRepositories`
  - `ecr:ListImages`
  - `ecr:DescribeImages`
  - `ecr:BatchGetImage`
- **Resource Scope**: `arn:aws:ecr:us-east-1:264765154707:repository/cluckin-bell-app`

#### SES Send Role: `GH_SES_Send_cluckin_bell_qa`
- **Purpose**: Send notification emails via AWS SES in QA environment
- **Trust Policy**: Restricted to `repo:oscarmartinez0880/cluckin-bell:environment:qa`
- **Permissions**:
  - `ses:SendEmail`
  - `ses:SendRawEmail`
- **Resource Scope**: All SES resources in `us-east-1` region

### Production Account (346746763840)

#### ECR Read Role: `GH_ECR_Read_cluckin_bell_app_prod`
- **Purpose**: Read ECR tags and metadata for the `cluckin-bell-app` repository in production
- **Trust Policy**: Restricted to `repo:oscarmartinez0880/cluckin-bell:environment:prod`
- **Permissions**:
  - `ecr:DescribeRepositories`
  - `ecr:ListImages`
  - `ecr:DescribeImages`
  - `ecr:BatchGetImage`
- **Resource Scope**: `arn:aws:ecr:us-east-1:346746763840:repository/cluckin-bell-app`

#### SES Send Role: `GH_SES_Send_cluckin_bell_prod`
- **Purpose**: Send notification emails via AWS SES in production environment
- **Trust Policy**: Restricted to `repo:oscarmartinez0880/cluckin-bell:environment:prod`
- **Permissions**:
  - `ses:SendEmail`
  - `ses:SendRawEmail`
- **Resource Scope**: All SES resources in `us-east-1` region

## Usage in GitHub Actions

### Prerequisites

1. Configure environment-scoped variables in the `oscarmartinez0880/cluckin-bell` repository
2. Ensure your workflow jobs include the required permissions for OIDC

### Required Job Permissions

```yaml
permissions:
  id-token: write
  contents: read
```

### Recommended Environment Variables

Configure these variables in GitHub → Settings → Environments:

#### QA Environment
```
AWS_ECR_READ_ROLE_ARN=arn:aws:iam::264765154707:role/GH_ECR_Read_cluckin_bell_app
AWS_SES_SEND_ROLE_ARN=arn:aws:iam::264765154707:role/GH_SES_Send_cluckin_bell_qa
```

#### Production Environment
```
AWS_ECR_READ_ROLE_ARN=arn:aws:iam::346746763840:role/GH_ECR_Read_cluckin_bell_app_prod
AWS_SES_SEND_ROLE_ARN=arn:aws:iam::346746763840:role/GH_SES_Send_cluckin_bell_prod
```

### Example Workflow Usage

#### ECR Tag Reading
```yaml
jobs:
  check-ecr-tags:
    runs-on: ubuntu-latest
    environment: qa  # or prod
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ECR_READ_ROLE_ARN }}
          aws-region: us-east-1

      - name: List ECR images
        run: |
          aws ecr describe-images \
            --repository-name cluckin-bell-app \
            --query 'imageDetails[*].imageTags' \
            --output text
```

#### SES Email Sending
```yaml
jobs:
  send-notification:
    runs-on: ubuntu-latest
    environment: qa  # or prod
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_SES_SEND_ROLE_ARN }}
          aws-region: us-east-1

      - name: Send email notification
        run: |
          aws ses send-email \
            --source oscar21martinez88@gmail.com \
            --destination ToAddresses=oscar21martinez88@gmail.com \
            --message Subject="{Data='Build Notification',Charset='UTF-8'}" \
                      Body="{Text={Data='Build completed successfully',Charset='UTF-8'}}"
```

## Security Features

- **Environment Scoping**: Each role is restricted to specific GitHub environment (`qa` or `prod`)
- **Repository Scoping**: Trust policies are limited to the `oscarmartinez0880/cluckin-bell` repository
- **Resource Scoping**: ECR permissions are limited to the `cluckin-bell-app` repository only
- **Regional Scoping**: SES permissions are restricted to `us-east-1` region
- **No Long-lived Credentials**: Uses OIDC tokens that expire automatically

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the workflow is running in the correct environment (qa/prod)
2. **Invalid OIDC Token**: Verify the `permissions` block includes `id-token: write`
3. **Role Assumption Failed**: Check that the repository name and environment match exactly

### Getting Role ARNs

To get the current role ARNs after deployment:

```bash
# Dev/QA account
cd terraform/accounts/devqa
terraform output ecr_read_role_arn
terraform output ses_send_role_arn

# Production account  
cd terraform/accounts/prod
terraform output ecr_read_role_arn
terraform output ses_send_role_arn
```

## Deployment

These roles are managed by Terraform in the account-level configurations:
- Dev/QA roles: `terraform/accounts/devqa/`
- Production roles: `terraform/accounts/prod/`

To deploy or update these roles:

```bash
# Deploy to dev/qa account
cd terraform/accounts/devqa
terraform init
terraform plan
terraform apply

# Deploy to production account
cd terraform/accounts/prod  
terraform init
terraform plan
terraform apply
```