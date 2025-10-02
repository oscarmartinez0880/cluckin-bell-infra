# Environments and Account Layout

This document describes the organizational structure, account layout, and environment-specific configurations for the Cluckin Bell infrastructure.

## Running Terraform (SSO)

### Simplified Workflow

Each environment now supports running `terraform` commands directly in the environment directory without extra flags:

- **Nonprod** (shared cluster in account 264765154707)
  ```bash
  aws sso login --profile cluckin-bell-qa
  cd envs/nonprod
  AWS_PROFILE=cluckin-bell-qa terraform init -upgrade
  AWS_PROFILE=cluckin-bell-qa terraform apply
  ```

- **Prod** (account 346746763840)
  ```bash
  aws sso login --profile cluckin-bell-prod
  cd envs/prod
  AWS_PROFILE=cluckin-bell-prod terraform init -upgrade
  AWS_PROFILE=cluckin-bell-prod terraform apply
  ```

### direnv Convenience (Linux/macOS)

For even simpler workflows, install and configure [direnv](https://direnv.net/):

```bash
# Install direnv (Ubuntu/Debian)
sudo apt install direnv

# Install direnv (macOS)
brew install direnv

# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
eval "$(direnv hook bash)"  # for bash
eval "$(direnv hook zsh)"   # for zsh
```

With direnv enabled, simply `cd` into an environment directory and run terraform directly:

```bash
# Nonprod
cd envs/nonprod   # direnv automatically sets AWS_PROFILE=cluckin-bell-qa
terraform init -upgrade
terraform apply

# Prod  
cd envs/prod      # direnv automatically sets AWS_PROFILE=cluckin-bell-prod
terraform init -upgrade
terraform apply
```

### Windows Users

Windows users can set the environment variable in PowerShell:

```powershell
# Nonprod
$env:AWS_PROFILE='cluckin-bell-qa'
cd envs/nonprod
terraform init -upgrade
terraform apply

# Prod
$env:AWS_PROFILE='cluckin-bell-prod'
cd envs/prod
terraform init -upgrade
terraform apply
```

Alternatively, enable direnv in WSL (Windows Subsystem for Linux) for the same convenience as Linux/macOS.

### How It Works

- **Backend configuration**: S3 backend settings are now embedded in each environment's `main.tf`
- **Auto-loaded variables**: Each environment has a `.auto.tfvars` file that loads automatically
- **AWS Profile**: Backend honors `AWS_PROFILE` environment variable (no need to set `profile` in backend config)

First-time bootstrap for a new cluster (two-phase apply):
```bash
cd envs/nonprod && terraform apply -target=module.eks
cd envs/prod && terraform apply -target=module.eks
```

### File Structure

Each environment maintains both original and auto-loaded variable files:
- envs/nonprod/devqa.tfvars (original, kept for reference)
- envs/nonprod/nonprod.auto.tfvars (auto-loaded copy)
- envs/prod/prod.tfvars (original, kept for reference)  
- envs/prod/prod.auto.tfvars (auto-loaded copy)

**Requirements**: Terraform >= 1.13.1 and Kubernetes >= 1.30 (default/target: 1.33)

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
| **dev** | 1.33 | eks.1 | Amazon Linux 2023 |
| **qa** | 1.33 | eks.1 | Amazon Linux 2023 |
| **prod** | 1.33 | eks.1 | Amazon Linux 2023 |

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

## EKS Cluster Version Management

### Important Note: Fixed kubernetes_version Issue
As of this update, the EKS module now properly honors the `cluster_version` variable (default 1.33) instead of the deprecated `kubernetes_version` variable (which defaulted to 1.28). This ensures the cluster is created with the intended Kubernetes version.

### Upgrading Existing Clusters

If you have an existing EKS cluster running Kubernetes 1.28, you have two options:

#### Option 1: In-Place Sequential Upgrade (Recommended for Production)

Kubernetes requires sequential upgrades between minor versions. To upgrade from 1.28 to 1.30:

```bash
# Step 1: Upgrade to 1.29
cd envs/nonprod
# Temporarily modify main.tf: cluster_version = "1.29"
AWS_PROFILE=cluckin-bell-qa terraform apply

# Wait for upgrade to complete (5-10 minutes)
kubectl get nodes  # Verify cluster is healthy

# Step 2: Upgrade to 1.30
# Modify main.tf: cluster_version = "1.30"
AWS_PROFILE=cluckin-bell-qa terraform apply
```

#### Option 2: Full Cluster Recreate (Nonprod Only)

For nonprod environments where downtime is acceptable:

```bash
# WARNING: This will destroy and recreate the cluster
cd envs/nonprod
AWS_PROFILE=cluckin-bell-qa terraform destroy -target=module.eks
AWS_PROFILE=cluckin-bell-qa terraform apply -target=module.eks

# Then apply the full configuration
AWS_PROFILE=cluckin-bell-qa terraform apply
```

### Dev/QA Environment Separation in Shared Cluster

The nonprod environment uses a single EKS cluster with the following separation strategies:

#### Namespace Isolation
- **Dev applications**: Deploy to `cluckin-bell-dev` namespace
- **QA applications**: Deploy to `cluckin-bell-qa` namespace
- **Platform components**: Shared in `kube-system`, `cluckin-bell`, etc.

#### DNS and Certificate Separation
- **Dev**: `*.dev.cluckn-bell.com` domain with dedicated Route53 zone
- **QA**: `*.qa.cluckn-bell.com` domain with dedicated Route53 zone
- **Internal**: Shared private zone `cluckn-bell.com` for cluster-internal services

#### IRSA and Secrets Separation
- **IRSA roles**: Environment-specific roles (e.g., `external-dns-dev`, `external-dns-qa`)
- **Secrets paths**: `/cluckn-bell/nonprod/*/dev/` and `/cluckn-bell/nonprod/*/qa/`

#### Optional Future Enhancements
If additional isolation is required, consider implementing:
- **NetworkPolicies**: Restrict pod-to-pod communication between namespaces
- **Resource Quotas**: Limit resource consumption per environment
- **Pod Security Standards**: Environment-specific security policies
- **Separate node groups**: Dedicated nodes per environment

## Running Terraform (SSO)

### Simplified Commands

- **Nonprod** (shared cluster in account 264765154707)
  ```bash
  aws sso login --profile cluckin-bell-qa
  cd envs/nonprod
  AWS_PROFILE=cluckin-bell-qa terraform init -upgrade
  AWS_PROFILE=cluckin-bell-qa terraform apply
  ```

- **Prod** (account 346746763840)
  ```bash
  aws sso login --profile cluckin-bell-prod
  cd envs/prod  
  AWS_PROFILE=cluckin-bell-prod terraform init -upgrade
  AWS_PROFILE=cluckin-bell-prod terraform apply
  ```

First-time bootstrap for a new cluster (two-phase apply):
```bash
cd envs/nonprod && terraform apply -target=module.eks
cd envs/prod && terraform apply -target=module.eks
```

**Note**: Backend configuration and variable files are now embedded in each environment, making commands OS-agnostic. The `.envrc` files provide optional direnv convenience for Linux/macOS users.