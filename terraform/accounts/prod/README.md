# Production Account Infrastructure

This Terraform configuration manages account-level AWS resources for the Production account (346746763840).

## Account Details

- **Account ID**: 346746763840
- **Environments**: prod
- **Region**: us-east-1

## Resources Created

### GitHub OIDC Provider
- **URL**: https://token.actions.githubusercontent.com
- **Thumbprint**: Dynamically derived from TLS certificate
- **Client ID**: sts.amazonaws.com

### EKS Deploy Roles
- `GH_EKS_Deploy_cb_prod_use1` - For production environment deployments

**Trust Policy**: Restricted to `oscarmartinez0880/cluckin-bell` repository with prod environment condition

### ECR Push Roles
- `GH_ECR_Push_cluckin_bell_app_prod` - For cluckin-bell-app production pushes
- `GH_ECR_Push_wingman_api_prod` - For wingman-api production pushes

**Trust Policy**: Restricted to specific repository and prod environment

### ECR Repositories
- `cluckin-bell-app`
- `wingman-api`

**Configuration**:
- Image scanning enabled
- Immutable tags
- Lifecycle policy keeps 50 images

## Usage

### Prerequisites

1. AWS CLI configured with access to account 346746763840
2. Terraform >= 1.0 installed
3. Appropriate IAM permissions

### Deployment

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### Using with Custom Variables

Copy the example tfvars file and customize:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values
terraform plan -var-file="terraform.tfvars"
```

## Outputs

After deployment, you'll get:

- **github_oidc_provider_arn**: ARN of the GitHub OIDC provider
- **eks_deploy_role_arns**: Map of environment to EKS deploy role ARNs (prod only)
- **ecr_push_role_arns**: Map of repository/environment to ECR push role ARNs
- **ecr_repository_urls**: Map of repository names to ECR URLs

## GitHub Actions Integration

Use these role ARNs in your GitHub Actions workflows:

### For EKS Deployments (cluckin-bell repository)

```yaml
jobs:
  deploy-prod:
    environment: prod
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_EKS_DEPLOY_ROLE_ARN_PROD }}
          aws-region: us-east-1
```

### For ECR Pushes (app repositories)

```yaml
jobs:
  push-to-ecr:
    environment: prod
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ECR_PUSH_ROLE_ARN }}
          aws-region: us-east-1
```

## Security

- All roles use GitHub OIDC for authentication (no long-lived credentials)
- ECR permissions are scoped to specific repositories
- EKS permissions are minimal (describe-only)
- Trust policies enforce repository and environment restrictions
- Production access requires explicit prod environment approval