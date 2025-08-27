# Account-Level AWS Infrastructure

This Terraform configuration manages account-level AWS resources for CI/CD without long-lived credentials across two AWS accounts.

## Account Structure

- **Dev/QA Account**: 264765154707 (`accounts/devqa/`)
- **Production Account**: 346746763840 (`accounts/prod/`)

All resources are deployed in the `us-east-1` region.

## Resources Managed

### 1. GitHub OIDC Providers
- One per account for GitHub Actions authentication
- Uses `data.tls_certificate` to derive thumbprints dynamically
- URL: `https://token.actions.githubusercontent.com`

### 2. IAM Roles for GitHub Actions

#### EKS Deploy Roles
- `GH_EKS_Deploy_cb_dev_use1` (Dev/QA account)
- `GH_EKS_Deploy_cb_qa_use1` (Dev/QA account)  
- `GH_EKS_Deploy_cb_prod_use1` (Prod account)

**Trust Policy**: Restricted to `oscarmartinez0880/cluckin-bell` repository with environment-specific conditions

**Permissions**: `eks:DescribeCluster` and other minimal EKS describe permissions

#### ECR Push Roles
Per account and repository combination:

**Dev/QA Account (264765154707)**:
- `GH_ECR_Push_cluckin_bell_app_dev`
- `GH_ECR_Push_wingman_api_dev`
- `GH_ECR_Push_cluckin_bell_app_qa`
- `GH_ECR_Push_wingman_api_qa`

**Prod Account (346746763840)**:
- `GH_ECR_Push_cluckin_bell_app_prod`
- `GH_ECR_Push_wingman_api_prod`

**Trust Policy**: Restricted to specific repository (`oscarmartinez0880/cluckin-bell-app` or `oscarmartinez0880/wingman-api`) and environment

**Permissions**: ECR push/pull actions for the specific repository only

### 3. ECR Repositories
- `cluckin-bell-app` in both accounts
- `wingman-api` in both accounts

**Configuration**:
- `image_scanning_configuration.scanOnPush = true`
- `image_tag_mutability = IMMUTABLE`
- Lifecycle policy to keep last 50 images

## Usage

### Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. IAM permissions to create OIDC providers, IAM roles, and ECR repositories

### Variables

Each account configuration accepts the following variables:

- `region`: AWS region (default: "us-east-1")
- `account_id`: AWS account ID
- `github_repository_owner`: GitHub repository owner (default: "oscarmartinez0880")
- `app_repositories`: List of application repositories (default: ["cluckin-bell-app", "wingman-api"])
- `environments`: List of environments for the account (default varies by account)

### Deployment

#### Dev/QA Account (264765154707)

```bash
cd accounts/devqa
terraform init
terraform plan
terraform apply
```

#### Production Account (346746763840)

```bash
cd accounts/prod
terraform init
terraform plan
terraform apply
```

### Cross-Account Deployment

To deploy to both accounts:

```bash
# Deploy Dev/QA account first
cd accounts/devqa
terraform init && terraform apply -auto-approve

# Deploy Prod account
cd ../prod
terraform init && terraform apply -auto-approve
```

## Outputs

Each account configuration outputs:

### GitHub OIDC Provider
- `github_oidc_provider_arn`: ARN of the GitHub OIDC provider

### EKS Deploy Roles
- `eks_deploy_role_arns`: Map of environment to EKS deploy role ARN

### ECR Push Roles
- `ecr_push_role_arns`: Map of repository and environment to ECR push role ARN

### ECR Repositories
- `ecr_repository_urls`: Map of repository name to ECR repository URL

## Security Considerations

1. **Least Privilege**: All IAM roles have minimal required permissions
2. **Repository Restrictions**: Trust policies are restricted to specific GitHub repositories
3. **Environment Restrictions**: Each role is restricted to specific GitHub environments
4. **Audience Validation**: All trust policies require `aud = sts.amazonaws.com`
5. **ECR Permissions**: ECR permissions are scoped to specific repository ARNs

## GitHub Actions Integration

To use these roles in GitHub Actions workflows:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: dev  # or qa, prod
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: us-east-1
```

Set the following repository variables:
- `AWS_ROLE_ARN`: The appropriate role ARN from the terraform outputs

## Naming Convention

Resources follow the naming convention:
- **EKS Deploy Roles**: `GH_EKS_Deploy_cb_{environment}_use1`
- **ECR Push Roles**: `GH_ECR_Push_{repository}_{environment}`
- **ECR Repositories**: `{repository-name}` (e.g., `cluckin-bell-app`, `wingman-api`)

## Troubleshooting

### Common Issues

1. **OIDC Provider Already Exists**: If you get an error that the OIDC provider already exists, you can import it:
   ```bash
   terraform import aws_iam_openid_connect_provider.github arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
   ```

2. **Permission Denied**: Ensure your AWS credentials have permissions to create IAM roles and ECR repositories

3. **Role Name Conflicts**: If role names conflict with existing roles, they can be imported or the existing roles can be renamed

### Validation

To validate the setup:

1. Check OIDC provider exists:
   ```bash
   aws iam list-open-id-connect-providers
   ```

2. Check roles exist:
   ```bash
   aws iam list-roles --query 'Roles[?starts_with(RoleName, `GH_`)]'
   ```

3. Check ECR repositories:
   ```bash
   aws ecr describe-repositories
   ```