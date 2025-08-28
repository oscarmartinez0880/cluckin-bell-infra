# Cluckin Bell Infrastructure

This Terraform configuration manages AWS infrastructure for the Cluckin Bell application across two AWS accounts.

## Requirements

- **Terraform**: Version ~> 1.13.1
- **AWS Provider**: Version ~> 5.60  
- **Helm Provider**: Version ~> 2.12
- **Kubernetes Provider**: Version ~> 2.33

## Account Structure

- **Dev/QA Account**: 264765154707 (`accounts/devqa/`)
- **Production Account**: 346746763840 (`accounts/prod/`)

All resources are deployed in the `us-east-1` region.

## Infrastructure Stacks

### 1. DNS Stack (`dns/`)
Creates Route53 hosted zones with apex in prod and NS delegation to dev and qa.

**Apply first** - other stacks depend on zone IDs from this stack.

```bash
cd dns
terraform init
terraform plan  
terraform apply
```

**Outputs**: `prod_apex_zone_id`, `dev_zone_id`, `qa_zone_id`

### 2. Cluster Stacks

#### Dev/QA Cluster (`clusters/devqa/`)
Creates shared EKS cluster for dev and qa environments with VPC, node groups, AWS Load Balancer Controller, and ExternalDNS.

**Variables required**:
- `dev_zone_id`: Output from DNS stack
- `qa_zone_id`: Output from DNS stack

```bash
cd clusters/devqa
terraform init
terraform plan -var="dev_zone_id=<dev_zone_id>" -var="qa_zone_id=<qa_zone_id>"
terraform apply -var="dev_zone_id=<dev_zone_id>" -var="qa_zone_id=<qa_zone_id>"
```

**Resources**: VPC (10.60.0.0/16), EKS 1.30 cluster (cb-use1-shared), managed node groups, ALB controller, ExternalDNS

#### Production Cluster (`clusters/prod/`)
Creates production EKS cluster with VPC, node groups, AWS Load Balancer Controller, and ExternalDNS.

**Variables required**:
- `prod_apex_zone_id`: Output from DNS stack

```bash
cd clusters/prod
terraform init
terraform plan -var="prod_apex_zone_id=<prod_apex_zone_id>"
terraform apply -var="prod_apex_zone_id=<prod_apex_zone_id>"
```

**Resources**: VPC (10.61.0.0/16), EKS 1.30 cluster (cb-use1-prod), managed node groups, ALB controller, ExternalDNS

### 3. Account-Level Resources (`accounts/`)
Contains existing account-level IAM roles, OIDC providers, and ECR repositories for CI/CD. These remain unchanged.

## Usage

### Prerequisites

1. AWS CLI configured with appropriate permissions for both accounts
2. Terraform ~> 1.13.1 installed  
3. IAM permissions to create VPC, EKS, Route53, OIDC providers, IAM roles, and ECR repositories

### Deployment Order

**Important**: Deploy stacks in this order due to dependencies:

1. **DNS stack first** (creates zone IDs needed by cluster stacks)
2. **Cluster stacks** (can be deployed in parallel, using zone IDs from DNS stack)

#### Complete Deployment Example

```bash
# 1. Deploy DNS stack first
cd dns
terraform init
terraform apply

# Get zone IDs from outputs
PROD_APEX_ZONE_ID=$(terraform output -raw prod_apex_zone_id)
DEV_ZONE_ID=$(terraform output -raw dev_zone_id) 
QA_ZONE_ID=$(terraform output -raw qa_zone_id)

# 2. Deploy Dev/QA cluster
cd ../clusters/devqa
terraform init
terraform apply -var="dev_zone_id=${DEV_ZONE_ID}" -var="qa_zone_id=${QA_ZONE_ID}"

# 3. Deploy Prod cluster  
cd ../prod
terraform init
terraform apply -var="prod_apex_zone_id=${PROD_APEX_ZONE_ID}"
```

### Account-Level Resources

Account-level IAM roles, OIDC providers, and ECR repositories are managed separately in the `accounts/` directory and remain unchanged. See existing documentation for those resources.

## Cluster Access

Once EKS clusters are deployed, you can access them using:

```bash
# Dev/QA cluster
aws eks update-kubeconfig --name cb-use1-shared --region us-east-1

# Prod cluster  
aws eks update-kubeconfig --name cb-use1-prod --region us-east-1
```

## GitHub Actions Integration

Account-level IAM roles for GitHub Actions CI/CD are configured separately in the `accounts/` directories. To use these roles in GitHub Actions workflows:

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
- `AWS_ROLE_ARN`: The appropriate role ARN from the account terraform outputs

## Resource Naming Conventions

- **EKS Clusters**: `cb-use1-shared` (Dev/QA), `cb-use1-prod` (Production)
- **VPCs**: `cb-devqa-use1` (Dev/QA), `cb-prod-use1` (Production)  
- **DNS Zones**: `cluckn-bell.com` (apex), `dev.cluckn-bell.com`, `qa.cluckn-bell.com`
- **IAM Roles**: `cb-external-dns-devqa`, `cb-external-dns-prod`

## Troubleshooting

### Common Issues

1. **Missing Zone IDs**: Ensure DNS stack is deployed first and zone ID variables are passed to cluster stacks

2. **EKS Access Denied**: The cluster creator has admin permissions by default. Ensure proper AWS credentials/role when accessing clusters

3. **ExternalDNS Issues**: Verify IAM permissions for Route53 zones and correct zone IDs in variables

### Validation

To validate the cluster setup:

1. Check EKS clusters exist:
   ```bash
   aws eks list-clusters --region us-east-1
   ```

2. Check Route53 zones:
   ```bash
   aws route53 list-hosted-zones
   ```

3. Verify kubectl access:
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```