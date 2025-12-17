# GitHub Actions Setup Guide

This guide provides step-by-step instructions for configuring GitHub repository variables required for the infrastructure automation workflows.

## Prerequisites

Before setting up GitHub Actions, ensure you have:
1. ✅ AWS accounts configured (nonprod: 264765154707, prod: 346746763840)
2. ✅ IAM OIDC providers created in each account
3. ✅ IAM roles created with proper trust policies
4. ✅ Admin access to the GitHub repository

## Required Repository Variables

The workflows reference these repository variables for AWS authentication via OIDC:

| Variable Name | Purpose | Example Value |
|--------------|---------|---------------|
| `AWS_TERRAFORM_ROLE_ARN_NONPROD` | Terraform deployment role for nonprod | `arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa` |
| `AWS_TERRAFORM_ROLE_ARN_PROD` | Terraform deployment role for prod | `arn:aws:iam::346746763840:role/cb-terraform-deploy-prod` |
| `AWS_EKSCTL_ROLE_ARN_NONPROD` | eksctl management role for nonprod | `arn:aws:iam::264765154707:role/cb-eksctl-manage-devqa` |
| `AWS_EKSCTL_ROLE_ARN_PROD` | eksctl management role for prod | `arn:aws:iam::346746763840:role/cb-eksctl-manage-prod` |

## Step-by-Step Configuration

### Step 1: Create IAM OIDC Provider (One-time per account)

Run this in **each AWS account** (nonprod and prod):

```bash
# Set your AWS profile
export AWS_PROFILE=cluckin-bell-qa  # or cluckin-bell-prod

# Create OIDC provider for GitHub Actions
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Verify creation
aws iam list-open-id-connect-providers
```

### Step 2: Create IAM Roles with Trust Policies

#### Nonprod Terraform Role (`cb-terraform-deploy-devqa`)

**Trust Policy** (`terraform-trust-policy-nonprod.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::264765154707:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:oscarmartinez0880/cluckin-bell-infra:*"
        }
      }
    }
  ]
}
```

**Create Role**:
```bash
# Set profile
export AWS_PROFILE=cluckin-bell-qa

# Create role
aws iam create-role \
  --role-name cb-terraform-deploy-devqa \
  --assume-role-policy-document file://terraform-trust-policy-nonprod.json

# Attach policies (adjust as needed for your security requirements)
aws iam attach-role-policy \
  --role-name cb-terraform-deploy-devqa \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Add inline policy for specific permissions if PowerUserAccess is too broad
```

#### Prod Terraform Role (`cb-terraform-deploy-prod`)

**Trust Policy** (`terraform-trust-policy-prod.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::346746763840:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:oscarmartinez0880/cluckin-bell-infra:*"
        }
      }
    }
  ]
}
```

**Create Role**:
```bash
# Set profile
export AWS_PROFILE=cluckin-bell-prod

# Create role
aws iam create-role \
  --role-name cb-terraform-deploy-prod \
  --assume-role-policy-document file://terraform-trust-policy-prod.json

# Attach policies
aws iam attach-role-policy \
  --role-name cb-terraform-deploy-prod \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
```

#### eksctl Roles

Create similar roles for eksctl with appropriate EKS management permissions:
- `cb-eksctl-manage-devqa` (nonprod account 264765154707)
- `cb-eksctl-manage-prod` (prod account 346746763840)

Required permissions for eksctl roles:
- `eks:*` - Full EKS permissions
- `ec2:*` - EC2 permissions for node groups
- `iam:CreateServiceLinkedRole` - For EKS service-linked roles
- `cloudformation:*` - eksctl uses CloudFormation
- `autoscaling:*` - For node group scaling

### Step 3: Configure GitHub Repository Variables

1. Navigate to your GitHub repository: https://github.com/oscarmartinez0880/cluckin-bell-infra
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click on the **Variables** tab
4. Add the following variables:

**Add each variable:**

| Variable Name | Value |
|--------------|-------|
| `AWS_TERRAFORM_ROLE_ARN_NONPROD` | `arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa` |
| `AWS_TERRAFORM_ROLE_ARN_PROD` | `arn:aws:iam::346746763840:role/cb-terraform-deploy-prod` |
| `AWS_EKSCTL_ROLE_ARN_NONPROD` | `arn:aws:iam::264765154707:role/cb-eksctl-manage-devqa` |
| `AWS_EKSCTL_ROLE_ARN_PROD` | `arn:aws:iam::346746763840:role/cb-eksctl-manage-prod` |

### Step 4: Verify Configuration

Test the setup by running a workflow:

1. Navigate to **Actions** → **Infrastructure Terraform**
2. Click **Run workflow**
3. Select:
   - Environment: `nonprod`
   - Action: `plan`
   - Region: `us-east-1`
4. Monitor the workflow run

If authentication fails, check:
- OIDC provider exists: `aws iam list-open-id-connect-providers`
- Role trust policy is correct: `aws iam get-role --role-name cb-terraform-deploy-devqa`
- Repository variables are set correctly in GitHub
- Trust policy includes correct repository name

## Security Best Practices

1. **Least Privilege**: Grant only the minimum permissions required
2. **Separate Roles**: Use different roles for Terraform and eksctl operations
3. **Repository Restrictions**: Limit trust policy to specific repository and branches
4. **Audit Logs**: Enable CloudTrail to track all role assumptions
5. **Regular Review**: Periodically review and update IAM policies

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Causes:**
- OIDC provider not created
- Trust policy missing or incorrect
- Repository name mismatch in trust policy

**Solution:**
```bash
# Verify OIDC provider
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com

# Check role trust policy
aws iam get-role --role-name ROLE_NAME --query 'Role.AssumeRolePolicyDocument'

# Verify repository name in trust policy matches: "repo:oscarmartinez0880/cluckin-bell-infra:*"
```

### Error: "Access Denied" during Terraform operations

**Causes:**
- Insufficient IAM permissions attached to role
- Missing policies for specific resources

**Solution:**
```bash
# List attached policies
aws iam list-attached-role-policies --role-name ROLE_NAME

# Add additional policies as needed
aws iam attach-role-policy \
  --role-name ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/POLICY_NAME
```

## Additional Resources

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Identity Providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [Runbook.md](Runbook.md) - Complete operational guide

---

**Last Updated**: 2024-01-15  
**Maintainer**: Infrastructure Team
