# EKS Cluster Recreate with Existing VPCs

This directory contains Terraform configurations to **recreate** EKS clusters using **existing** VPCs and subnets, after the previous clusters were manually deleted.

## Purpose

The existing environments in `/envs/nonprod` and `/envs/prod` create VPCs from scratch. This new approach:
- **Reuses existing VPCs** and tagged subnets 
- **Recreates only the EKS clusters** that were manually deleted
- **Enables platform GitOps scaffolding** for add-ons already planned in the `cluckin-bell` repo

## Directory Structure

```
terraform/
├── README.md
├── nonprod-eks/          # Shared Dev/QA cluster in nonprod account (264765154707)
│   ├── backend.hcl       # S3 backend: cluckn-bell-tfstate-nonprod
│   ├── main.tf           # EKS cluster definition using terraform-aws-modules/eks ~> 20.x
│   ├── variables.tf      # VPC ID, subnet IDs, cluster version, tags
│   ├── outputs.tf        # Cluster details, OIDC provider ARN
│   └── terraform.tfvars.example
└── prod-eks/             # Dedicated production cluster in prod account (346746763840)
    ├── backend.hcl       # S3 backend: cluckn-bell-tfstate-prod
    ├── main.tf           # EKS cluster definition
    ├── variables.tf      # VPC ID, subnet IDs, cluster version, tags
    ├── outputs.tf        # Cluster details, OIDC provider ARN
    └── terraform.tfvars.example
```

## Features

- **Kubernetes Version**: >= 1.30 with production-safe defaults
- **Existing VPC Integration**: Uses provided VPC ID and subnet IDs (no VPC recreation)
- **Node Groups**: 
  - Nonprod: separate `dev` and `qa` node groups with env labels
  - Prod: single `prod` node group
- **Logging**: All control plane log types enabled (api, audit, authenticator, controllerManager, scheduler)
- **IRSA**: OIDC provider enabled for platform add-ons
- **Core Add-ons**: coredns, kube-proxy, vpc-cni with compatible versions

## Prerequisites

### 1. Existing Infrastructure
- VPC with properly tagged subnets
- Public subnets tagged with `kubernetes.io/role/elb` 
- Private subnets tagged with `kubernetes.io/role/internal-elb`

### 2. AWS CLI Profiles
- `cluckin-bell-qa` for nonprod account (264765154707)
- `cluckin-bell-prod` for prod account (346746763840)

### 3. S3 Backend Buckets
- `cluckn-bell-tfstate-nonprod` 
- `cluckn-bell-tfstate-prod`

## Subnet Information

Based on the problem statement, these are the existing subnets to use:

### Nonprod (Account 264765154707)
**Public subnets (kubernetes.io/role/elb tagged):**
- `subnet-09a601564fef30599` (us-east-1a)
- `subnet-0e428ee488b3accac` (us-east-1b)
- `subnet-00205cdb6865588ac` (us-east-1c)

**Private subnets (kubernetes.io/role/internal-elb tagged):**
- `subnet-0d1a90b43e2855061` (us-east-1a)
- `subnet-0e408dd3b79d3568b` (us-east-1b)
- `subnet-00d5249fbe0695848` (us-east-1c)

### Prod (Account 346746763840)
**Public subnets (kubernetes.io/role/elb tagged):**
- `subnet-058d9ae9ff9399cb6` (us-east-1a)
- `subnet-0fd7aac0afed270b0` (us-east-1b)
- `subnet-06b04efdad358c264` (us-east-1c)

**Private subnets (kubernetes.io/role/internal-elb tagged):**
- `subnet-09722cf26237fc552` (us-east-1a)
- `subnet-0fb6f763ab136eb0b` (us-east-1b)
- `subnet-0bbb317a18c2a6386` (us-east-1c)

## Usage

### Step 1: Get VPC IDs

First, determine the VPC ID for the provided subnets:

```bash
# For nonprod subnets
NONPROD_VPC_ID=$(aws ec2 describe-subnets \
  --subnet-ids subnet-09a601564fef30599 \
  --profile cluckin-bell-qa \
  --query 'Subnets[0].VpcId' \
  --output text)
echo "Nonprod VPC ID: $NONPROD_VPC_ID"

# For prod subnets  
PROD_VPC_ID=$(aws ec2 describe-subnets \
  --subnet-ids subnet-058d9ae9ff9399cb6 \
  --profile cluckin-bell-prod \
  --query 'Subnets[0].VpcId' \
  --output text)
echo "Prod VPC ID: $PROD_VPC_ID"
```

### Step 2: Deploy Nonprod Cluster

```bash
cd terraform/nonprod-eks

# Initialize with backend configuration
terraform init -backend-config=backend.hcl

# Plan the deployment
terraform plan \
  -var "aws_profile=cluckin-bell-qa" \
  -var "vpc_id=$NONPROD_VPC_ID" \
  -var 'public_subnet_ids=["subnet-09a601564fef30599","subnet-0e428ee488b3accac","subnet-00205cdb6865588ac"]' \
  -var 'private_subnet_ids=["subnet-0d1a90b43e2855061","subnet-0e408dd3b79d3568b","subnet-00d5249fbe0695848"]'

# Apply the configuration
terraform apply \
  -var "aws_profile=cluckin-bell-qa" \
  -var "vpc_id=$NONPROD_VPC_ID" \
  -var 'public_subnet_ids=["subnet-09a601564fef30599","subnet-0e428ee488b3accac","subnet-00205cdb6865588ac"]' \
  -var 'private_subnet_ids=["subnet-0d1a90b43e2855061","subnet-0e408dd3b79d3568b","subnet-00d5249fbe0695848"]'
```

### Step 3: Deploy Prod Cluster

```bash
cd terraform/prod-eks

# Initialize with backend configuration
terraform init -backend-config=backend.hcl

# Plan the deployment
terraform plan \
  -var "aws_profile=cluckin-bell-prod" \
  -var "vpc_id=$PROD_VPC_ID" \
  -var 'public_subnet_ids=["subnet-058d9ae9ff9399cb6","subnet-0fd7aac0afed270b0","subnet-06b04efdad358c264"]' \
  -var 'private_subnet_ids=["subnet-09722cf26237fc552","subnet-0fb6f763ab136eb0b","subnet-0bbb317a18c2a6386"]'

# Apply the configuration  
terraform apply \
  -var "aws_profile=cluckin-bell-prod" \
  -var "vpc_id=$PROD_VPC_ID" \
  -var 'public_subnet_ids=["subnet-058d9ae9ff9399cb6","subnet-0fd7aac0afed270b0","subnet-06b04efdad358c264"]' \
  -var 'private_subnet_ids=["subnet-09722cf26237fc552","subnet-0fb6f763ab136eb0b","subnet-0bbb317a18c2a6386"]'
```

## Post-Deployment Steps

### 1. Update Kubeconfig

```bash
# Nonprod cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name cluckn-bell-nonprod \
  --profile cluckin-bell-qa

# Prod cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name cluckn-bell-prod \
  --profile cluckin-bell-prod
```

### 2. Bootstrap Argo CD

Bootstrap Argo CD (nonprod then prod) from the `cluckin-bell` application repository.

### 3. Deploy Platform Add-ons

Sync the platform-addons application to deploy ExternalDNS in nonprod.

### 4. Validate ExternalDNS

```bash
kubectl -n external-dns logs deploy/external-dns | head
```

## Outputs

Each cluster configuration provides the following outputs:

- `cluster_name`: EKS cluster name
- `cluster_endpoint`: Cluster API endpoint  
- `cluster_version`: Kubernetes version
- `cluster_certificate_authority_data`: Base64 CA certificate
- `oidc_provider_arn`: OIDC provider ARN for IRSA
- `node_group_names`: List of managed node group names
- `private_subnet_ids`: Private subnet IDs used
- `public_subnet_ids`: Public subnet IDs used  
- `vpc_id`: VPC ID where cluster is deployed

## Security Notes

- **API Endpoint**: Currently allows public access from all CIDRs (0.0.0.0/0)
  - TODO: Restrict to specific IP ranges for production hardening
- **Worker Nodes**: Deployed only in private subnets for security
- **IRSA**: Enabled for secure service account access to AWS services

## Follow-up Tasks (Not in Scope)

- [ ] Create IAM roles for platform add-ons (ExternalDNS, ALB Controller, cert-manager)
- [ ] Switch nonprod ExternalDNS to zone-id-filter mode (needs all zone IDs confirmed)
- [ ] Implement API endpoint CIDR restrictions
- [ ] Rename prod subnets from devqa-* to prod-* (requires zero-downtime plan)