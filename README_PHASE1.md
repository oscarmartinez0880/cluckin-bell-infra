# Cluckin Bell Infrastructure - Phase 1

This repository contains Terraform infrastructure as code for Cluckin Bell Phase 1 deployment across nonprod and prod AWS accounts.

## Overview

### Architecture

- **Nonprod Account (264765154707)**: Single EKS cluster with dev and qa node groups
- **Prod Account (346746763840)**: Dedicated EKS cluster for production
- **Region**: us-east-1 (all resources)
- **DNS**: Hierarchical zone structure with delegation
- **Security**: IRSA for service accounts, KMS encryption, least privilege IAM

### Key Features

- **EKS Clusters**:
  - Nonprod: `cluckn-bell-nonprod` with ng-dev and ng-qa node groups
  - Prod: `cluckn-bell-prod` with ng-prod node group
  - Kubernetes 1.29, t3.small instances for cost optimization

- **DNS Management**:
  - Prod: apex zone `cluckn-bell.com`
  - Nonprod: subdomains `dev.cluckn-bell.com` and `qa.cluckn-bell.com`
  - NS delegation from prod to nonprod subdomains

- **TLS Certificates**:
  - ACM wildcard certificates with DNS validation
  - `*.cluckn-bell.com`, `*.dev.cluckn-bell.com`, `*.qa.cluckn-bell.com`

- **Container Registry**:
  - Shared ECR repository `cluckin-bell-app`
  - Lifecycle policy (keep last 10 images)

- **Service Accounts (IRSA)**:
  - AWS Load Balancer Controller
  - External DNS (environment-scoped)
  - Cluster Autoscaler
  - AWS for Fluent Bit
  - External Secrets

- **Observability**:
  - CloudWatch log groups with 1-day retention
  - Structured logging for clusters and applications

- **Identity & Access**:
  - Cognito user pools for authentication
  - GitHub OIDC for CI/CD ECR access
  - Admin users in nonprod, empty prod pool

- **Secrets Management**:
  - AWS Secrets Manager for WordPress and MariaDB credentials
  - Environment-specific secret paths

## Repository Structure

```
├── bootstrap/                 # S3 state bucket creation
│   ├── nonprod/              # Nonprod account bucket
│   └── prod/                 # Prod account bucket
├── envs/                     # Environment-specific infrastructure  
│   ├── nonprod/              # All nonprod resources (account 264765154707)
│   └── prod/                 # Prod resources (account 346746763840)
├── modules_new/              # Reusable Terraform modules
│   ├── vpc/                  # VPC with 3-AZ subnets, single NAT
│   ├── eks/                  # EKS cluster with configurable node groups
│   ├── route53_zone/         # Hosted zones with delegation support
│   ├── acm/                  # ACM certificates with DNS validation
│   ├── ecr/                  # ECR repository with lifecycle policy
│   ├── irsa/                 # IRSA roles for service accounts
│   ├── cognito/              # Cognito user pools and clients
│   ├── github_oidc/          # GitHub OIDC provider and roles
│   ├── cloudwatch/           # CloudWatch log groups
│   └── secrets/              # Secrets Manager with generated passwords
└── README.md                 # This file
```

## Prerequisites

1. **AWS CLI configured** with appropriate credentials for both accounts
2. **Terraform >= 1.0** installed
3. **Account Access**:
   - Nonprod account: 264765154707 (cluckin-bell-qa)
   - Prod account: 346746763840 (cluckin-bell-prod)
4. **IAM Permissions**: Administrative access for initial bootstrap

## Deployment Instructions

### Phase 1: Bootstrap (S3 State Buckets)

Create S3 buckets for Terraform state management in each account.

#### 1. Bootstrap Nonprod Account

```bash
# Configure AWS credentials for nonprod account (264765154707)
export AWS_PROFILE=cluckin-bell-qa

cd bootstrap/nonprod
terraform init
terraform plan
terraform apply
```

#### 2. Bootstrap Prod Account  

```bash
# Configure AWS credentials for prod account (346746763840)
export AWS_PROFILE=cluckin-bell-prod

cd ../prod
terraform init  
terraform plan
terraform apply
```

### Phase 2: Deploy Nonprod Environment

```bash
# Configure AWS credentials for nonprod account
export AWS_PROFILE=cluckin-bell-qa

cd ../../envs/nonprod
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# Note the name servers output for dev and qa zones
terraform output dev_zone_name_servers
terraform output qa_zone_name_servers
```

**Important**: Save the name server outputs - you'll need them for the prod deployment.

### Phase 3: Deploy Prod Environment

```bash
# Configure AWS credentials for prod account  
export AWS_PROFILE=cluckin-bell-prod

cd ../prod

# Create terraform.tfvars with name servers from nonprod
cat > terraform.tfvars << EOF
dev_zone_name_servers = [
  "ns-xxx.awsdns-xx.com.",
  "ns-xxx.awsdns-xx.co.uk.", 
  "ns-xxx.awsdns-xx.net.",
  "ns-xxx.awsdns-xx.org."
]
qa_zone_name_servers = [
  "ns-xxx.awsdns-xx.com.",
  "ns-xxx.awsdns-xx.co.uk.",
  "ns-xxx.awsdns-xx.net.", 
  "ns-xxx.awsdns-xx.org."
]
EOF

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Infrastructure Components

### Networking

- **VPC CIDR**: 
  - Nonprod: `10.0.0.0/16`
  - Prod: `10.1.0.0/16`
- **Subnets**: 3 AZs with public/private subnets
- **NAT**: Single NAT Gateway for cost optimization
- **Security**: Default security groups, EKS-managed additional groups

### EKS Configuration

#### Nonprod Cluster (`cluckn-bell-nonprod`)
- **Node Groups**:
  - `ng-dev`: t3.small, desired=1, min=1, max=2, labels: env=dev
  - `ng-qa`: t3.small, desired=1, min=1, max=2, labels: env=qa
- **Version**: Kubernetes 1.29
- **Networking**: Private workers, public API endpoint

#### Prod Cluster (`cluckn-bell-prod`)  
- **Node Groups**:
  - `ng-prod`: t3.small, desired=2, min=2, max=3, labels: env=prod
- **Version**: Kubernetes 1.29
- **Networking**: Private workers, public API endpoint

### DNS Hierarchy

```
cluckn-bell.com (prod account)
├── dev.cluckn-bell.com (delegated to nonprod)
└── qa.cluckn-bell.com (delegated to nonprod)
```

### IRSA Roles

Each environment includes service account roles for:

- **AWS Load Balancer Controller**: ALB/NLB management
- **External DNS**: 
  - Nonprod: Separate roles for dev/qa zones with unique txtOwnerId
  - Prod: Single role for apex zone
- **Cluster Autoscaler**: Node group scaling
- **AWS for Fluent Bit**: CloudWatch logs shipping  
- **External Secrets**: Secrets Manager access

### Secrets Structure

```
/cluckn-bell/
├── nonprod/
│   ├── wordpress/dev/  (database, auth)
│   ├── wordpress/qa/   (database, auth)  
│   ├── mariadb/dev/    (credentials)
│   └── mariadb/qa/     (credentials)
└── prod/
    ├── wordpress/prod/ (database, auth)
    └── mariadb/prod/   (credentials)
```

## Key Outputs for Application Deployment

After successful deployment, use these outputs for Kubernetes manifests:

### Nonprod Environment
```bash
cd envs/nonprod
terraform output -json > nonprod-outputs.json
```

### Prod Environment  
```bash
cd envs/prod
terraform output -json > prod-outputs.json
```

### Important ARNs for IRSA
- AWS Load Balancer Controller: `aws_load_balancer_controller_role_arn`
- External DNS: `external_dns_*_role_arn`  
- Cluster Autoscaler: `cluster_autoscaler_role_arn`
- AWS for Fluent Bit: `aws_for_fluent_bit_role_arn`
- External Secrets: `external_secrets_role_arn`

### GitHub Actions ECR Access
- ECR Push Role: `github_ecr_push_role_arn`
- Repository URL: `ecr_repository_url`

## Tagging Strategy

All resources are tagged with:
- `Application`: cluckn-bell
- `Environment`: nonprod|prod  
- `Owner`: oscarmartinez0880
- `ManagedBy`: terraform

## Cost Optimization

- **Compute**: t3.small instances across all environments
- **Networking**: Single NAT Gateway per VPC
- **Logging**: 1-day retention for CloudWatch logs
- **Storage**: Lifecycle policies for ECR (keep 10 images)

## Security Features

- **Encryption**: KMS encryption for EKS secrets
- **IAM**: Least privilege IRSA roles with environment scoping
- **Networking**: Private subnets for workers, security groups
- **Secrets**: AWS Secrets Manager with generated passwords
- **Access**: Cognito authentication for admin interfaces

## Troubleshooting

### Common Issues

1. **Name Server Propagation**: DNS delegation may take time to propagate
2. **Certificate Validation**: ACM certificates require DNS records to exist
3. **ECR Cross-Account**: Same repository name creates resource conflicts

### Validation Commands

```bash
# Check EKS cluster status
aws eks describe-cluster --name cluckn-bell-nonprod --region us-east-1

# Verify Route53 delegation  
dig NS dev.cluckn-bell.com
dig NS qa.cluckn-bell.com

# Test certificate validation
aws acm describe-certificate --certificate-arn <cert-arn> --region us-east-1

# Validate IRSA configuration
aws iam get-role --role-name cluckn-bell-nonprod-aws-load-balancer-controller
```

## Next Steps (Phase 2)

After Phase 1 completion:
1. Deploy Kubernetes controllers using IRSA role ARNs
2. Configure external-dns with environment-specific txtOwnerIDs
3. Set up monitoring and alerting
4. Deploy application workloads with Secrets Manager integration
5. Configure CI/CD pipelines with GitHub OIDC roles

## Support

For issues or questions:
- Repository: https://github.com/oscarmartinez0880/cluckin-bell-infra  
- Owner: oscarmartinez0880
- Environment: Phase 1 Infrastructure Setup