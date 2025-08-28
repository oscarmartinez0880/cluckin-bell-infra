# EKS Root Stack Deployment Guide

This guide explains how to deploy the root EKS stack using the Terraform Deploy workflow. The root EKS stack provisions EKS clusters and related resources from the repository root.

## When to Use the Root EKS Stack

Use the root EKS stack when you want to deploy a complete EKS environment with:
- EKS cluster with Windows and Linux node groups
- Kubernetes controllers (AWS Load Balancer Controller, cert-manager, external-dns)
- ArgoCD for GitOps
- ECR repositories
- Route53 zones and DNS management

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

#### For Development Environment
- **Target environment**: `dev`
- **Working directory**: `.` (repository root)
- **Optional -var-file path**: `examples/tfvars/dev.us-east-1.tfvars`
- **Apply**: `false` for plan, `true` to apply

#### For QA Environment
- **Target environment**: `qa`
- **Working directory**: `.` (repository root)
- **Optional -var-file path**: `examples/tfvars/qa.us-east-1.tfvars`
- **Apply**: `false` for plan, `true` to apply

#### For Production Environment
- **Target environment**: `prod`
- **Working directory**: `.` (repository root)
- **Optional -var-file path**: `examples/tfvars/prod.us-east-1.tfvars`
- **Apply**: `false` for plan, `true` to apply

### Environment Separation

- **Dev and QA**: Share the same nonprod account (`264765154707`) but can be planned/applied separately by switching var-files
- **Production**: Uses its own dedicated account (`346746763840`) with separate IAM roles

## Version Requirements

- **Terraform**: 1.13.1 (pinned in workflow)
- **Kubernetes**: Minimum 1.30 (as configured in example tfvars)

## Deployment Steps

1. **Plan First**: Always run with `apply: false` to review changes
   ```
   Target environment: dev
   Working directory: .
   Optional -var-file path: examples/tfvars/dev.us-east-1.tfvars
   Apply: false
   ```

2. **Review Plan Output**: Check the planned resources in the workflow logs

3. **Apply Changes**: Run again with `apply: true` if the plan looks correct
   ```
   Target environment: dev
   Working directory: .
   Optional -var-file path: examples/tfvars/dev.us-east-1.tfvars
   Apply: true
   ```

4. **Repeat for Other Environments**: Use the appropriate var-file for each environment

## What Gets Deployed

Each environment deployment creates:
- EKS cluster named `cb-{env}-use1`
- Linux and Windows node groups with environment-specific sizing
- AWS Load Balancer Controller for ingress
- cert-manager for TLS certificate automation
- external-dns for Route53 DNS management
- ArgoCD for GitOps (syncs from CodeCommit)
- ECR repositories for application images
- Required IAM roles and policies (IRSA)

## Troubleshooting

### Common Issues
- **VPC not found**: Ensure VPCs exist with correct naming convention
- **IAM role assumption failed**: Verify GitHub environment variables and account-level Terraform deployment
- **Kubernetes version errors**: Ensure version ≥ 1.30 in tfvars files

### Validation
- Check GitHub environment variables are correctly configured
- Verify account-level infrastructure is deployed
- Ensure VPC and subnet resources exist and are properly tagged