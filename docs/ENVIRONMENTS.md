# Environments and Account Layout

This document describes the organizational structure, account layout, and environment-specific configurations for the Cluckin Bell infrastructure.

## Account Structure

The infrastructure is organized across two AWS accounts following a clear separation of concerns:

| Account | Environment(s) | Purpose | Account ID |
|---------|----------------|---------|------------|
| **DevQA** | dev, qa | Development and QA workloads, shared resources | 123456789012 |
| **Production** | prod | Production workloads, isolated and secure | 987654321098 |

## Environment Overview

### Multi-Environment EKS Strategy

Each environment runs on its own dedicated EKS cluster with environment-specific configurations:

| Environment | Cluster Name | Account | VPC CIDR | Namespace | Domain |
|-------------|--------------|---------|----------|-----------|--------|
| **dev** | cb-dev-use1 | DevQA | 10.0.0.0/16 | cluckin-bell | dev.cluckin-bell.com |
| **qa** | cb-qa-use1 | DevQA | 10.1.0.0/16 | cluckin-bell | qa.cluckin-bell.com |
| **prod** | cb-prod-use1 | Production | 10.2.0.0/16 | cluckin-bell | cluckin-bell.com |

### Shared DevQA Account Model

The DevQA account houses both development and QA environments with the following benefits:

- **Cost Optimization**: Shared account-level resources (ECR repositories, Route 53 hosted zones)
- **VPC Peering**: Direct connectivity between dev and qa environments for integration testing
- **Shared Bastion**: Single SSM bastion host provides access to both environments
- **Simplified IAM**: Common IRSA roles and policies across dev/qa environments

## Technology Versions

### Kubernetes Versions

| Environment | Kubernetes Version | EKS Platform Version | Node AMI |
|-------------|-------------------|---------------------|----------|
| **dev** | 1.30 | eks.1 | Amazon Linux 2023 |
| **qa** | 1.30 | eks.1 | Amazon Linux 2023 |
| **prod** | 1.30 | eks.1 | Amazon Linux 2023 |

### Terraform Versions

| Component | Version Constraint | Purpose |
|-----------|-------------------|---------|
| **Terraform Core** | >= 1.0 | Infrastructure as Code engine |
| **AWS Provider** | ~> 5.0 | AWS resource management |
| **Kubernetes Provider** | ~> 2.20 | Kubernetes resource management |
| **Helm Provider** | ~> 2.0 | Helm chart deployments |

### Platform Component Versions

| Component | Version | Purpose |
|-----------|---------|---------|
| **AWS Load Balancer Controller** | 1.8.1 | Ingress and load balancer management |
| **cert-manager** | v1.15.3 | TLS certificate automation |
| **external-dns** | 1.14.5 | DNS record automation |
| **ArgoCD** | 7.6.12 | GitOps application deployment |

## Network Architecture

### VPC Configuration

Each environment has a dedicated VPC with the following characteristics:

#### Development Environment (10.0.0.0/16)
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24 (AZ a, b)
- **Private Subnets**: 10.0.10.0/24, 10.0.20.0/24 (AZ a, b)
- **NAT Gateway**: Single NAT in AZ-a (cost optimization)
- **VPC Peering**: Connected to QA environment

#### QA Environment (10.1.0.0/16)
- **Public Subnets**: 10.1.1.0/24, 10.1.2.0/24 (AZ a, b)
- **Private Subnets**: 10.1.10.0/24, 10.1.20.0/24 (AZ a, b)
- **NAT Gateway**: Single NAT in AZ-a (cost optimization)
- **VPC Peering**: Connected to dev environment

#### Production Environment (10.2.0.0/16)
- **Public Subnets**: 10.2.1.0/24, 10.2.2.0/24 (AZ a, b)
- **Private Subnets**: 10.2.10.0/24, 10.2.20.0/24 (AZ a, b)
- **NAT Gateways**: Dual NAT for high availability (AZ a, b)
- **Network Isolation**: No VPC peering to dev/qa

### VPC Peering Configuration

Dev ↔ QA VPC peering enables:
- **Cross-environment testing**: QA can validate integrations with dev services
- **Shared resources access**: Both environments can use shared dev bastion
- **Data synchronization**: Safe data pipeline testing between environments

## DNS and Domain Management

### Route 53 Hosted Zones

| Domain | Zone ID | Account | Purpose |
|--------|---------|---------|---------|
| **cluckin-bell.com** | Z1D633PJN98FT9 | Production | Production public domain |
| **dev.cluckin-bell.com** | Z2FDTNDATAQYW2 | DevQA | Development subdomain |
| **qa.cluckin-bell.com** | Z3G5CAV3H4YUZ3 | DevQA | QA subdomain |

### DNS Management Strategy

- **external-dns**: Automatically manages DNS records for Ingress resources
- **Certificate automation**: cert-manager uses DNS01 challenges for wildcard certificates
- **Environment isolation**: Each environment manages only its own domain records

## Security and Access Management

### IAM Roles for Service Accounts (IRSA)

Each environment has dedicated IRSA roles for platform components:

| Component | Dev Role ARN | QA Role ARN | Prod Role ARN |
|-----------|--------------|-------------|---------------|
| **AWS Load Balancer Controller** | arn:aws:iam::123456789012:role/cb-dev-alb-controller | arn:aws:iam::123456789012:role/cb-qa-alb-controller | arn:aws:iam::987654321098:role/cb-prod-alb-controller |
| **cert-manager** | arn:aws:iam::123456789012:role/cb-dev-cert-manager | arn:aws:iam::123456789012:role/cb-qa-cert-manager | arn:aws:iam::987654321098:role/cb-prod-cert-manager |
| **external-dns** | arn:aws:iam::123456789012:role/cb-dev-external-dns | arn:aws:iam::123456789012:role/cb-qa-external-dns | arn:aws:iam::987654321098:role/cb-prod-external-dns |

### GitHub OIDC Integration

CI/CD authentication uses GitHub OIDC providers for keyless authentication:

| Account | OIDC Provider ARN | Allowed Repositories |
|---------|-------------------|---------------------|
| **DevQA** | arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com | oscarmartinez0880/cluckin-bell-infra |
| **Production** | arn:aws:iam::987654321098:oidc-provider/token.actions.githubusercontent.com | oscarmartinez0880/cluckin-bell-infra |

### Bastion Host Access

| Environment | Bastion Instance | Access Method | Connection |
|-------------|-----------------|---------------|------------|
| **dev/qa** | cb-devqa-bastion | SSM Session Manager | Shared access to both environments |
| **prod** | cb-prod-bastion | SSM Session Manager | Production-only access |

## Resource Scaling by Environment

### EKS Node Groups

| Environment | Node Group | Instance Types | Min | Desired | Max |
|-------------|------------|----------------|-----|---------|-----|
| **dev** | cb-dev-linux | m5.large, m5.xlarge | 1 | 2 | 5 |
| **qa** | cb-qa-linux | m5.large, m5.xlarge | 1 | 3 | 8 |
| **prod** | cb-prod-linux | m5.xlarge, m5.2xlarge | 2 | 5 | 15 |

### Application Resource Limits

| Environment | CPU Request | CPU Limit | Memory Request | Memory Limit | Replicas |
|-------------|-------------|-----------|----------------|--------------|----------|
| **dev** | 100m | 500m | 128Mi | 512Mi | 1 |
| **qa** | 200m | 1000m | 256Mi | 1Gi | 2 |
| **prod** | 500m | 2000m | 512Mi | 2Gi | 3+ (HPA) |

## GitOps Configuration

### Repository Structure

```
oscarmartinez0880/cluckin-bell-infra/
├── stacks/environments/          # Infrastructure definitions
│   ├── dev/                     # Dev environment stack
│   ├── qa/                      # QA environment stack
│   └── prod/                    # Prod environment stack
└── modules/                     # Reusable Terraform modules
    ├── k8s-controllers/         # Platform controllers
    ├── eks/                     # EKS cluster configuration
    └── vpc/                     # VPC and networking

oscarmartinez0880/cluckin-bell/   # Application repository
├── k8s/                         # Kubernetes manifests
│   ├── dev/                     # Dev application configs
│   ├── qa/                      # QA application configs
│   └── prod/                    # Prod application configs
└── helm/                        # Helm charts and values
```

### ArgoCD Application Sources

| Environment | ArgoCD Namespace | Git Repository | Target Path | Sync Policy |
|-------------|------------------|----------------|-------------|-------------|
| **dev** | cluckin-bell | oscarmartinez0880/cluckin-bell | k8s/dev | Auto-sync enabled |
| **qa** | cluckin-bell | oscarmartinez0880/cluckin-bell | k8s/qa | Manual sync |
| **prod** | cluckin-bell | oscarmartinez0880/cluckin-bell | k8s/prod | Manual sync |

## Environment-Specific Behaviors

### Development Environment
- **Auto-sync**: ArgoCD automatically deploys changes from git
- **Resource limits**: Minimal resources for cost optimization
- **Certificates**: Let's Encrypt staging for testing
- **Monitoring**: Basic CloudWatch integration
- **Data persistence**: Non-persistent storage for rapid iteration

### QA Environment
- **Manual sync**: Controlled deployments for testing stability
- **Resource limits**: Production-like sizing for realistic testing
- **Certificates**: Let's Encrypt production for realistic TLS testing
- **Monitoring**: Enhanced monitoring with alerts
- **Data persistence**: Persistent storage for integration testing

### Production Environment
- **Manual sync**: Strict change control and approval processes
- **High availability**: Multi-AZ NAT gateways and redundant components
- **Auto-scaling**: HPA configured for application workloads
- **Certificates**: Let's Encrypt production with monitoring
- **Monitoring**: Full observability stack with alerting
- **Data persistence**: Highly available, backed up persistent storage

## Cost Optimization Strategies

### DevQA Account
- **Shared NAT Gateway**: Single NAT per environment saves ~$90/month
- **Shared Bastion**: One bastion for both dev/qa saves ~$15/month
- **VPC Peering**: Eliminates need for VPN or Transit Gateway
- **Right-sized instances**: Smaller instances for non-production workloads

### Production Account
- **Dual NAT**: High availability over cost optimization
- **Dedicated resources**: Isolated for security and performance
- **Auto-scaling**: Scale down during off-hours
- **Reserved instances**: Commit to reserved capacity for baseline load

## Compliance and Governance

### Tagging Strategy
All resources include consistent tags:
- **Environment**: dev, qa, prod
- **Project**: cluckin-bell
- **ManagedBy**: terraform
- **Stack**: Specific stack name (network, platform-eks, etc.)

### Backup Strategy
- **EBS Snapshots**: Daily snapshots with 7-day retention (dev/qa), 30-day retention (prod)
- **RDS Backups**: Automated backups with point-in-time recovery
- **Configuration Backups**: Terraform state in S3 with versioning

### Security Scanning
- **Image Scanning**: ECR vulnerability scanning enabled
- **Infrastructure Scanning**: Terraform security scanning in CI/CD
- **Secrets Management**: AWS Secrets Manager for sensitive data
- **Network Security**: Security groups with least privilege access