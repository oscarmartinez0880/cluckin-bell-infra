# Environment Configuration

This directory contains environment-specific Terraform configurations for the Cluckin' Bell infrastructure.

## Structure

- `nonprod/` - Development and QA environment (shared cluster in account 264765154707)
- `prod/` - Production environment (dedicated cluster in account 346746763840)

## Unified EKS Cluster Provisioning

The infrastructure supports both creating new VPCs/subnets and reusing existing network artifacts:

### Network Configuration Options

**Option 1: Create New VPC/Subnets** (default)
- Set `existing_vpc_id = ""` (empty)
- Terraform will create new VPC and subnets using the vpc module

**Option 2: Reuse Existing VPC/Subnets** (current setup)
- Set `existing_vpc_id` to an existing VPC ID
- Provide lists of `public_subnet_ids` and `private_subnet_ids`
- Terraform will use the existing network infrastructure

### EKS Cluster Features

- **Multiple Node Groups**: Each environment creates explicit node groups
  - Nonprod: `dev` and `qa` node groups
  - Prod: `prod` node group
- **Enhanced Logging**: Configurable CloudWatch retention (30 days nonprod, 90 days prod)
- **Encryption**: KMS encryption enabled with module-provisioned keys
- **API Access**: Configurable CIDR restrictions (currently open, ready for tightening)

## Variable Files

Each environment has a comprehensive `.tfvars` file with network and EKS configuration:

- `nonprod/nonprod.tfvars` - All configuration for the nonprod environment
- `prod/prod.tfvars` - All configuration for the production environment

## File Structure

Each environment contains:
- `main.tf` - Core infrastructure (DNS, ECR, monitoring, IRSA roles)
- `network.tf` - VPC/subnet selection logic
- `eks-cluster.tf` - EKS cluster configuration
- `node-groups.tf` - Explicit node group definitions
- `variables.tf` - Variable declarations
- `*.tfvars` - Variable assignments

## Usage

### Deploy Nonprod Environment
```bash
cd envs/nonprod
aws sso login --profile cluckin-bell-qa
terraform init
terraform plan -var-file=nonprod.tfvars -out=nonprod.plan
terraform apply nonprod.plan
aws eks update-kubeconfig --name cluckn-bell-nonprod --profile cluckin-bell-qa --region us-east-1
kubectl get nodes
```

### Deploy Prod Environment
```bash
cd envs/prod
aws sso login --profile cluckin-bell-prod
terraform init
terraform plan -var-file=prod.tfvars -out=prod.plan
terraform apply prod.plan
aws eks update-kubeconfig --name cluckn-bell-prod --profile cluckin-bell-prod --region us-east-1
kubectl get nodes
```

### Verify Node Groups
```bash
aws eks describe-nodegroup \
  --cluster-name cluckn-bell-nonprod \
  --nodegroup-name dev \
  --query 'nodegroup.nodeRole' \
  --profile cluckin-bell-qa --region us-east-1
```

## Current Network Configuration

**Nonprod VPC:** `vpc-0749517f2c92924a5`
- Public subnets: `subnet-09a601564fef30599`, `subnet-0e428ee488b3accac`, `subnet-00205cdb6865588ac`
- Private subnets: `subnet-0d1a90b43e2855061`, `subnet-0e408dd3b79d3568b`, `subnet-00d5249fbe0695848`

**Prod VPC:** `vpc-0c33a4bf182550b55`
- Public subnets: `subnet-058d9ae9ff9399cb6`, `subnet-0fd7aac0afed270b0`, `subnet-06b04efdad358c264`
- Private subnets: `subnet-09722cf26237fc552`, `subnet-0fb6f763ab136eb0b`, `subnet-0bbb317a18c2a6386`

## DNS Configuration

### Nonprod Environment
- Route53 zones: `dev.cluckn-bell.com`, `qa.cluckn-bell.com`
- Private zone: `cluckn-bell.com` (shared)

### Prod Environment
- Route53 zones: `cluckn-bell.com` (root domain)
- NS delegations for dev/qa subdomains from nonprod account

## Name Server Configuration

The production environment requires name servers from the nonprod environment for subdomain delegation:

1. Deploy nonprod environment first
2. Get name servers: `terraform output dev_zone_name_servers qa_zone_name_servers`
3. Update `prod.tfvars` with the actual name server values
4. Deploy production environment

## Security Considerations

- **API Access**: Currently set to `0.0.0.0/0` with TODO comments for tightening
- **Encryption**: KMS encryption enabled for EKS secrets
- **IRSA**: Granular IAM roles for service accounts

## Future Enhancements

Separate PRs suggested for:
- IRSA IAM roles for ExternalDNS and ALB Controller
- API endpoint CIDR restrictions
- Cluster autoscaler configuration
- KMS key aliasing and rotation policies