# EKS Root Stack Deployment Guide

This guide explains how to deploy the root EKS stack using the Terraform Deploy workflow. The root EKS stack provisions EKS clusters and related resources from the repository root.

## When to Use the Root EKS Stack

Use the root EKS stack when you want to deploy a complete EKS environment with:
- **VPC and networking** (subnets, route tables)
- **IAM roles for service accounts** (IRSA for AWS Load Balancer Controller, cert-manager, external-dns)
- **ECR repositories**
- **Route53 zones and DNS management**
- **Cognito user pools**
- **Secrets Manager secrets**

**Important**: The root EKS stack does **not** create EKS clusters. Use **eksctl** to create clusters after Terraform provisions the VPC/networking. eksctl is the single source of truth for cluster lifecycle management.

This is different from the account-level stacks (`terraform/accounts/devqa` and `terraform/accounts/prod`) which provision IAM roles, OIDC providers, and other bootstrap resources.

## Deployment Using Terraform Deploy Workflow

### Prerequisites

1. **Account-level infrastructure must be deployed first** to create the required IAM roles and OIDC providers:
   - Deploy `terraform/accounts/devqa` for dev/qa environments
   - Deploy `terraform/accounts/prod` for production environment

2. **GitHub Environment Variables** must be configured:
   - Dev: `AWS_TERRAFORM_ROLE_ARN = arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa`
   - QA: `AWS_TERRAFORM_ROLE_ARN = arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa`
   - Prod: `AWS_TERRAFORM_ROLE_ARN = arn:aws:iam::346746763840:role/cb-terraform-deploy-prod`

3. **VPC Prerequisites**: Ensure VPCs exist with proper naming (e.g., `dev-vpc`, `qa-vpc`, `prod-vpc`) as referenced by the data sources in `main.tf`.

### Workflow Parameters

When running **Actions → Terraform Deploy → Run workflow**, use these parameters:

#### For Development Environment (NonProd)
- **Target environment**: `dev`
- **Working directory**: `envs/nonprod`
- **Apply**: `false` for plan, `true` to apply

#### For QA Environment (NonProd)
- **Target environment**: `qa`
- **Working directory**: `envs/nonprod`
- **Apply**: `false` for plan, `true` to apply

#### For Production Environment
- **Target environment**: `prod`
- **Working directory**: `envs/prod`
- **Apply**: `false` for plan, `true` to apply

### Environment Separation

- **Dev and QA**: Share the same nonprod account (`264765154707`) and use the same environment stack (`envs/nonprod`)
- **Production**: Uses its own dedicated account (`346746763840`) with its own environment stack (`envs/prod`)

## Version Requirements

- **Terraform**: 1.13.1 (pinned in workflow)
- **Kubernetes**: Minimum 1.30 (as configured in environment terraform.tfvars)

## Deployment Steps

### Phase 1: Terraform for VPC and Networking

1. **Plan First**: Always run with `apply: false` to review changes
   ```
   Target environment: dev
   Working directory: envs/nonprod
   Apply: false
   ```

2. **Review Plan Output**: Check the planned resources in the workflow logs

3. **Apply Changes**: Run again with `apply: true` if the plan looks correct
   ```
   Target environment: dev
   Working directory: envs/nonprod
   Apply: true
   ```

### Phase 2: eksctl for EKS Cluster

After Terraform creates the VPC and subnets:

```bash
# Get VPC and subnet IDs from Terraform outputs
cd envs/nonprod
terraform output vpc_id
terraform output private_subnet_ids

# Update eksctl/devqa-cluster.yaml with actual VPC/subnet IDs
# Then create the cluster with eksctl
eksctl create cluster --config-file=../../eksctl/devqa-cluster.yaml --profile=cluckin-bell-qa
```

### Phase 3: Terraform for Remaining Components

After the eksctl cluster is created, run Terraform again to provision IAM roles and other resources that depend on the cluster:

```bash
terraform apply
```

## What Gets Deployed

Each environment deployment creates:
- VPC and subnets (if not using existing)
- **EKS cluster via eksctl** (see `docs/CLUSTERS_WITH_EKSCTL.md`)
  - Nonprod: `cluckn-bell-nonprod`
  - Prod: `cluckn-bell-prod`
- Node groups managed by eksctl with environment-specific sizing
- IAM roles for service accounts (IRSA) for:
  - AWS Load Balancer Controller
  - cert-manager
  - external-dns
  - Cluster Autoscaler
  - Fluent Bit
  - External Secrets
- ECR repositories for application images
- Route53 zones and DNS management
- Cognito user pools
- Secrets Manager secrets

## Troubleshooting

### Common Issues
- **VPC not found**: Ensure VPCs exist with correct naming convention
- **IAM role assumption failed**: Verify GitHub environment variables and account-level Terraform deployment
- **Kubernetes version errors**: Ensure version ≥ 1.30 in environment terraform.tfvars files

### Validation
- Check GitHub environment variables are correctly configured
- Verify account-level infrastructure is deployed
- Ensure VPC and subnet resources exist and are properly tagged