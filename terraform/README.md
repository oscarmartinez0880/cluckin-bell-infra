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

**Resources**: VPC (10.60.0.0/16), EKS 1.30 cluster (cb-use1-shared), managed node groups, ALB controller, ExternalDNS (with internal zone support), SSM bastion

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

**Resources**: VPC (10.61.0.0/16), EKS 1.30 cluster (cb-use1-prod), managed node groups, ALB controller, ExternalDNS (with internal zone support), KMS secrets encryption, VPC endpoints, SSM bastion

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
  - **Internal Zones**: `internal.dev.cluckn-bell.com` (Dev/QA), `internal.cluckn-bell.com` (Prod)
- **IAM Roles**: `cb-external-dns-devqa`, `cb-external-dns-prod`
- **Bastion Hosts**: `cb-devqa-bastion`, `cb-prod-bastion`

## Private CMS Access and Internal Infrastructure

### Internal DNS Zones

The infrastructure includes private Route53 hosted zones for internal service access:

- **Dev/QA**: `internal.dev.cluckn-bell.com` (private zone associated with Dev/QA VPC)
- **Production**: `internal.cluckn-bell.com` (private zone associated with Prod VPC)

These zones enable split-horizon DNS for routing to internal ALBs while keeping public DNS unchanged.

### ExternalDNS Internal Zone Management

ExternalDNS is configured to manage both public and internal zones with high availability:

- **Replicas**: 2 pods with pod disruption budget (minAvailable: 1)
- **Domain Filters**: Includes both public and internal zones
- **Anti-affinity**: Spreads replicas across nodes for reliability
- **Security**: Runs as non-root with resource limits

Example internal ALB ingress:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cms-internal
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    external-dns.alpha.kubernetes.io/hostname: cms.internal.cluckn-bell.com
spec:
  rules:
  - host: cms.internal.cluckn-bell.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: cms-service
            port:
              number: 80
```

### SSM Bastion Hosts

Secure access to private resources is provided via SSM Session Manager bastion hosts:

#### Dev/QA Shared Bastion
- **Instance**: `cb-devqa-bastion` (t3.micro)
- **Access**: Both dev and qa environments
- **Network**: Public subnet with no inbound security group rules

#### Production Dedicated Bastion
- **Instance**: `cb-prod-bastion` (t3.micro)  
- **Access**: Production environment only
- **Network**: Public subnet with no inbound security group rules

#### Bastion Access Examples

**Direct shell access:**
```bash
# Get bastion instance ID from Terraform output
DEV_BASTION_ID=$(cd clusters/devqa && terraform output -raw bastion_devqa_instance_id)
PROD_BASTION_ID=$(cd clusters/prod && terraform output -raw bastion_prod_instance_id)

# Connect via SSM Session Manager
aws ssm start-session --target $DEV_BASTION_ID
aws ssm start-session --target $PROD_BASTION_ID
```

**Port forwarding to internal services:**
```bash
# Forward local port 8080 to internal CMS on port 80
aws ssm start-session --target $PROD_BASTION_ID \
  --document-name AWS-StartPortForwardingSession \
  --parameters portNumber=80,localPortNumber=8080

# Access internal service at http://localhost:8080
```

**Prerequisites for SSM access:**
1. AWS CLI configured with appropriate permissions
2. Session Manager plugin installed:
   ```bash
   # macOS
   brew install --cask session-manager-plugin
   
   # Ubuntu/Debian
   curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
   sudo dpkg -i session-manager-plugin.deb
   ```

### EKS API Endpoint Security

#### Current Configuration
- **Public + Private Access**: EKS API endpoints are currently accessible from any IP
- **Future CIDR Restrictions**: Infrastructure is prepared for restricting public API access

#### Future CIDR Allowlisting

Variables are available to restrict EKS API access to specific CIDR blocks:

```bash
# Dev/QA cluster with restricted API access
terraform apply -var="api_public_cidrs_devqa=[\"203.0.113.0/24\",\"198.51.100.0/24\"]"

# Production cluster with restricted API access  
terraform apply -var="api_public_cidrs_prod=[\"203.0.113.0/24\"]"
```

**Common use cases for CIDR restrictions:**
- **GitHub Actions runners**: Restrict to GitHub's IP ranges
- **VPN networks**: Limit access to corporate VPN CIDR blocks
- **Office networks**: Allow access only from company IP ranges

**Getting GitHub Actions IP ranges:**
```bash
curl -s https://api.github.com/meta | jq -r '.actions[]' 
```

### Security Features

#### Production KMS Encryption
- **Enabled**: EKS secrets envelope encryption using AWS KMS
- **Key Rotation**: Automatic annual key rotation enabled
- **Scope**: Kubernetes secrets only (resources=["secrets"])

#### VPC Endpoints (Production Parity)
Production includes VPC endpoints for cost optimization and security:
- **S3 Gateway**: Cost-effective S3 access from private subnets
- **ECR API/DKR**: Container image pulls without NAT gateway
- **SSM Endpoints**: Bastion connectivity without public internet

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

2. Check Route53 zones (including internal zones):
   ```bash
   aws route53 list-hosted-zones
   ```

3. Verify kubectl access:
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

4. Test internal zone resolution from bastion:
   ```bash
   # Connect to bastion
   aws ssm start-session --target $(cd clusters/prod && terraform output -raw bastion_prod_instance_id)
   
   # Test internal DNS resolution
   nslookup internal.cluckn-bell.com
   ```

5. Verify ExternalDNS manages internal zones:
   ```bash
   # Check ExternalDNS logs
   kubectl logs -n default -l app.kubernetes.io/name=external-dns
   
   # Verify internal zone has TXT records
   aws route53 list-resource-record-sets --hosted-zone-id <internal_zone_id>
   ```

6. Test KMS encryption in production:
   ```bash
   # Create a test secret
   kubectl create secret generic test-secret --from-literal=key=value
   
   # Verify it's encrypted (check AWS console or describe the secret)
   kubectl describe secret test-secret
   ```