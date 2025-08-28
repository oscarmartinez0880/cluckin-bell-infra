# EKS Clusters and DNS Infrastructure

This directory contains Terraform configurations for EKS clusters and DNS management across dev/qa/prod environments.

## Directory Structure

- `versions.tf` - Root-level version constraints for Terraform and providers
- `clusters/devqa/` - Shared EKS cluster for dev and qa environments (account: 264765154707)
- `clusters/prod/` - Dedicated EKS cluster for production (account: 346746763840)
- `dns/` - DNS zones and delegation configuration

## Architecture Overview

### Accounts
- **Dev/QA Account**: 264765154707 (hosts shared dev+qa cluster and sub-zones)
- **Production Account**: 346746763840 (hosts prod cluster and apex zone)

### Clusters
- **DevQA Cluster**: `cb-use1-shared` (shared between dev/qa, 2 nodes min)
- **Prod Cluster**: `cb-use1-prod` (dedicated production, 3 nodes min)

Both clusters include:
- EKS 1.30 with managed node groups (m5.large instances)
- AWS Load Balancer Controller for ALB/NLB management
- ExternalDNS for automatic DNS record management (public and internal zones)
- Private subnets with single NAT gateway for cost optimization
- SSM bastion hosts for secure private access
- KMS secrets encryption (enabled in production)
- VPC endpoints for cost optimization and security

### DNS Strategy
- **Apex Zone**: `cluckn-bell.com` hosted in production account
- **Sub-zones**: `dev.cluckn-bell.com` and `qa.cluckn-bell.com` hosted in dev/qa account
- **Delegation**: NS records in apex zone delegate sub-zones to dev/qa account
- **Internal Zones**: `internal.dev.cluckn-bell.com` (dev/qa) and `internal.cluckn-bell.com` (prod) for private services
- **Delegation**: NS records in apex zone delegate sub-zones to dev/qa account

## Deployment Order

1. **DNS Stack**: Deploy first to create zones and delegation
   ```bash
   cd terraform/dns
   terraform init
   terraform apply
   ```

2. **DevQA Cluster**: Deploy with zone IDs from DNS outputs
   ```bash
   cd terraform/clusters/devqa
   terraform init
   terraform apply -var="dev_zone_id=<from_dns_output>" -var="qa_zone_id=<from_dns_output>"
   ```

3. **Prod Cluster**: Deploy with apex zone ID from DNS outputs
   ```bash
   cd terraform/clusters/prod
   terraform init
   terraform apply -var="prod_apex_zone_id=<from_dns_output>"
   ```

## Security Features

- **IRSA (IAM Roles for Service Accounts)**: Each controller uses minimal permissions
- **Network Isolation**: Private subnets for worker nodes
- **Domain Filtering**: ExternalDNS limited to specific hosted zones (public and internal)
- **Resource Tagging**: Consistent tagging for cost tracking and governance
- **KMS Encryption**: EKS secrets envelope encryption enabled in production
- **SSM Bastion Access**: Secure access to private resources without inbound SSH
- **VPC Endpoints**: Reduce NAT gateway costs and improve security for AWS services
- **EKS API Security**: Prepared for future CIDR allowlisting to restrict API access

### Bastion Host Access

**Dev/QA Shared Bastion** (account: 264765154707):
```bash
# Get instance ID
DEV_BASTION_ID=$(cd clusters/devqa && terraform output -raw bastion_devqa_instance_id)

# Connect via SSM
aws ssm start-session --target $DEV_BASTION_ID
```

**Production Dedicated Bastion** (account: 346746763840):
```bash
# Get instance ID  
PROD_BASTION_ID=$(cd clusters/prod && terraform output -raw bastion_prod_instance_id)

# Connect via SSM
aws ssm start-session --target $PROD_BASTION_ID
```

### Internal CMS Access

Use internal ALB with private DNS zones for CMS access:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cms-internal
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internal
    external-dns.alpha.kubernetes.io/hostname: cms.internal.cluckn-bell.com
spec:
  rules:
  - host: cms.internal.cluckn-bell.com
    # ... rest of ingress configuration
```

## Version Requirements

- Terraform: ~> 1.13.1
- AWS Provider: ~> 5.60
- Helm Provider: ~> 2.12
- Kubernetes Provider: ~> 2.33

This infrastructure is designed to be non-destructive to existing account-level resources (GitHub OIDC, IAM roles, ECR repositories) and provides a foundation for deploying the Cluckin' Bell application across multiple environments.