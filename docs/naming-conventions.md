# Cluckin' Bell Naming Conventions

This document serves as the authoritative source for all naming conventions used in the Cluckin' Bell AWS infrastructure. All names follow a fried-chicken theme for consistency and fun.

## Core Values

- **Project**: cluckin-bell
- **Region**: us-east-1 (single-region deployment)
- **Environments**: dev, qa, prod

## AWS Accounts

| Environment | Account ID | Alias |
|-------------|------------|-------|
| dev | 264765154707 | cluckin-bell-qa |
| qa | 264765154707 | cluckin-bell-qa |
| prod | 346746763840 | cluckin-bell-prod |

## EKS Clusters

**Naming Pattern**: `cluckin-bell-eks-{env}-{region}`

| Environment | Cluster Name |
|-------------|--------------|
| dev | cluckin-bell-eks-dev-us-east-1 |
| qa | cluckin-bell-eks-qa-us-east-1 |
| prod | cluckin-bell-eks-prod-us-east-1 |

## Kubernetes Namespaces

- `cluckin-bell-dev`
- `cluckin-bell-qa`
- `cluckin-bell-prod`

## IAM Roles (IRSA)

**Naming Patterns**:
- ECR Pull Role: `cb-ecr-pull-role-{env}`
- App Web Service Account Role: `cb-app-web-sa-role-{env}`
- API Service Account Role: `cb-api-sa-role-{env}`

| Role Type | dev | qa | prod |
|-----------|-----|-----|------|
| ECR Pull | cb-ecr-pull-role-dev | cb-ecr-pull-role-qa | cb-ecr-pull-role-prod |
| App Web SA | cb-app-web-sa-role-dev | cb-app-web-sa-role-qa | cb-app-web-sa-role-prod |
| API SA | cb-api-sa-role-dev | cb-api-sa-role-qa | cb-api-sa-role-prod |

## ECR Repositories

All ECR repositories follow fried-chicken themed naming:

- `cluckin-bell-app` - Main application container
- `wingman-api` - API service container  
- `fryer-worker` - Background worker container
- `sauce-gateway` - Gateway/proxy container
- `clucker-notify` - Notification service container

## S3 Buckets

**Naming Pattern**: `cluckin-bell-{purpose}-{env}-{region}`

| Purpose | dev | qa | prod |
|---------|-----|-----|------|
| Logs | cluckin-bell-logs-dev-us-east-1 | cluckin-bell-logs-qa-us-east-1 | cluckin-bell-logs-prod-us-east-1 |
| Artifacts | cluckin-bell-artifacts-dev-us-east-1 | cluckin-bell-artifacts-qa-us-east-1 | cluckin-bell-artifacts-prod-us-east-1 |
| Static Assets | cluckin-bell-static-dev-us-east-1 | cluckin-bell-static-qa-us-east-1 | cluckin-bell-static-prod-us-east-1 |

## KMS Key Aliases

- `alias/cb-ecr` - ECR encryption
- `alias/cb-secrets` - Secrets encryption
- `alias/cb-logs` - Log encryption

## CloudWatch Log Groups

**Naming Pattern**: `/cluckin-bell/{service}/{env}`

| Service | dev | qa | prod |
|---------|-----|-----|------|
| Drumstick Web | /cluckin-bell/drumstick-web/dev | /cluckin-bell/drumstick-web/qa | /cluckin-bell/drumstick-web/prod |
| Wingman API | /cluckin-bell/wingman-api/dev | /cluckin-bell/wingman-api/qa | /cluckin-bell/wingman-api/prod |
| Fryer Worker | /cluckin-bell/fryer-worker/dev | /cluckin-bell/fryer-worker/qa | /cluckin-bell/fryer-worker/prod |

## Standard Tags

All resources should include these standard tags:

```hcl
tags = {
  Project   = "cluckin-bell"
  Env       = var.environment  # dev, qa, or prod
  ManagedBy = "terraform"
  Region    = "us-east-1"
}
```

## Usage in Terraform

Reference these naming conventions using the locals defined in `locals/naming.tf`:

```hcl
# Example: Create an EKS cluster with standard naming
resource "aws_eks_cluster" "main" {
  name = local.eks_cluster_name
  tags = local.tags
}

# Example: Create ECR repositories
resource "aws_ecr_repository" "repos" {
  for_each = toset(local.ecr_repositories)
  name     = each.value
  tags     = local.tags
}

# Example: Create S3 bucket with standard naming
resource "aws_s3_bucket" "logs" {
  bucket = local.s3_buckets.logs
  tags   = local.tags
}
```