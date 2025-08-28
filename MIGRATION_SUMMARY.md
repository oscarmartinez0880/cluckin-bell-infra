# Infrastructure Migration Summary

## Overview

This document summarizes the infrastructure changes implemented to support:
1. Domain migration from `cluckin-bell.com` to `cluckn-bell.com`
2. S3-only backend for Terraform state (no DynamoDB)
3. Private Argo CD access via internal ALB with TLS
4. GitHub App authentication for private repositories

## Changes Implemented

### 1. Domain Migration (cluckin-bell.com → cluckn-bell.com)

**Files Updated:**
- `main.tf` - Domain locals and external-dns filter
- `locals/naming.tf` - Domain configuration
- `variables.tf` - Default email address
- `modules/k8s-controllers/variables.tf` - Domain filter description
- `docs/domains.md` - All domain references
- `README.md` - Documentation
- `env/*.tfvars` - Environment-specific configurations

**Domains:**
- **Development**: `dev.cluckn-bell.com`, `api.dev.cluckn-bell.com`
- **QA**: `qa.cluckn-bell.com`, `api.qa.cluckn-bell.com` 
- **Production**: `cluckn-bell.com`, `api.cluckn-bell.com`

### 2. S3 Backend for Terraform State

**New Stack:** `stacks/s3-backend/`
- **Bucket naming**: `tfstate-cluckn-bell-{account-id}`
- **Features**: Versioning, encryption (SSE-S3), public access blocked, lifecycle policy
- **Retention**: Configurable days for non-current versions (default: 30)
- **No DynamoDB**: S3-only backend as requested

**Updated Files:**
- `backend.tf` - Updated configuration and instructions
- `backend.hcl.example` - Removed DynamoDB reference
- `README.md` - Added backend setup instructions

### 3. Route53 Hosted Zones

**New File:** `route53.tf`
- **Public Zone**: `cluckn-bell.com` for ACME challenges and public records
- **Private Zone**: `cluckn-bell.com` per environment for internal services
- **VPC Association**: Private zone associated with cluster VPC
- **IAM Policies**: Least-privilege access for external-dns and cert-manager

### 4. Enhanced External-DNS Configuration

**Updates in:** `modules/k8s-controllers/`
- **Zone ID Filters**: Support for managing both public and private zones
- **Domain Filters**: Updated for cluckn-bell.com
- **Dual Zone Management**: Public zone for ACME, private zone for internal ALBs

### 5. Argo CD with Internal ALB

**New Components:**
- **Namespace**: `argocd` namespace creation
- **Helm Release**: Argo CD with internal ALB configuration
- **Ingress Configuration**:
  - **Scheme**: `internal` (not internet-facing)
  - **Target Type**: `ip` for direct pod targeting
  - **TLS**: cert-manager with Let's Encrypt
  - **Hostnames**: Environment-specific (argocd.{env}.cluckn-bell.com)

**GitHub App Authentication:**
- **Secret Creation**: `argocd-repo-creds` for GitHub App credentials
- **Variables**: `github_app_id`, `github_app_installation_id`, `github_app_private_key`
- **Repository Access**: Configured for `oscarmartinez0880/cluckin-bell.git`

### 6. Cluster Naming

**Updated to match specifications:**
- **Development**: `cb-dev-use1`
- **QA**: `cb-qa-use1`
- **Production**: `cb-prod-use1`

## Deployment Instructions

### Bootstrap S3 Backend
```bash
cd stacks/s3-backend
terraform init
terraform apply -var-file="../../env/dev.tfvars"
```

### Configure Backend
```bash
cp backend.hcl.example backend.hcl
# Edit backend.hcl with your account ID
terraform init -backend-config=backend.hcl -migrate-state
```

### Deploy Infrastructure
```bash
terraform plan -var-file="env/dev.tfvars"
terraform apply -var-file="env/dev.tfvars"
```

## Access Methods

### Argo CD Access

1. **VPC Connectivity** (Production):
   - VPN connection to VPC
   - Bastion host access
   - Direct network connectivity

2. **kubectl Port-Forward** (Development):
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name cb-dev-use1
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Access at https://localhost:8080
   ```

3. **Admin Password**:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

## GitHub App Setup

1. Create GitHub App with repository permissions
2. Set Terraform variables:
   ```hcl
   github_app_id               = "123456"
   github_app_installation_id = "12345678"  
   github_app_private_key      = "base64-encoded-key"
   ```

## Outputs

The infrastructure provides these key outputs:
- `public_hosted_zone_id` - For DNS delegation
- `public_hosted_zone_name_servers` - NS records for domain setup
- `private_hosted_zone_id` - For internal DNS
- `argocd_url` - Direct URL to Argo CD (requires VPC access)
- `argocd_kubectl_port_forward_command` - Command for local access

## Validation

All Terraform configurations validated successfully:
- ✅ Main configuration (`terraform validate`)
- ✅ S3 backend stack (`terraform validate`)
- ✅ Plan execution test (credentials needed for full deployment)