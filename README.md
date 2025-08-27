# Cluckin Bell Infrastructure

This repository contains Terraform infrastructure as code for the Cluckin Bell application, providing multi-environment EKS clusters with GitOps using ArgoCD.

## Architecture Overview

### Multi-Environment Setup

The infrastructure is organized around environment-specific EKS clusters:

| Environment | Cluster Name | VPC CIDR | ArgoCD Git Path | Domain |
|-------------|--------------|----------|------------------|--------|
| **dev** | cb-dev-use1 | 10.0.0.0/16 | k8s/dev | dev.cluckin-bell.com |
| **qa** | cb-qa-use1 | 10.1.0.0/16 | k8s/qa | qa.cluckin-bell.com |
| **prod** | cb-prod-use1 | 10.2.0.0/16 | k8s/prod | cluckin-bell.com |

### GitOps Architecture

- **Platform Components** (Terraform-managed): VPC, EKS, external-dns, cert-manager, ArgoCD
- **Application Workloads** (ArgoCD-managed): All apps from [`oscarmartinez0880/cluckin-bell`](https://github.com/oscarmartinez0880/cluckin-bell) repository
- **Single Namespace Strategy**: All components deployed to `cluckin-bell` namespace per cluster

## Repository Structure

```
├── stacks/environments/          # Environment-specific infrastructure
│   ├── dev/                     # Development EKS cluster
│   ├── qa/                      # QA EKS cluster  
│   ├── prod/                    # Production EKS cluster
│   └── README.md                # Environment deployment guide
├── modules/                     # Reusable Terraform modules
│   ├── vpc/                     # VPC with subnets, NAT gateways
│   ├── k8s-controllers/         # Platform controllers (ALB, cert-manager, external-dns)
│   ├── argocd/                  # ArgoCD GitOps setup
│   └── ...
├── terraform/accounts/          # Account-level resources (IAM, ECR)
│   ├── devqa/                   # Dev/QA account resources
│   └── prod/                    # Production account resources
└── deploy-environments.sh       # Multi-environment deployment script
```

## Infrastructure Architecture

The infrastructure is organized into 5 Terraform stacks following a modular approach:

- **bootstrap**: GitHub OIDC IAM roles and foundational security resources
- **network**: VPC, subnets, security groups, and networking resources  
- **platform-eks**: EKS cluster, node groups, and Kubernetes platform resources
- **data**: RDS databases, Redis clusters, and data storage resources
- **registry-obsv**: ECR repositories and observability infrastructure

## Structure


- **Terraform Infrastructure**: Main Terraform configuration for EKS clusters with Windows support
- `env/`: Environment-specific Terraform variable files (dev, qa, prod)
- `k8s/{dev,qa,prod}/`: All Kubernetes manifests for each environment
- `helm/`: Helm values per environment and role
- `k8s-monitoring/`: Full Prometheus+Grafana monitoring stack and dashboards

---

## Infrastructure Overview

### EKS Cluster Configuration

The platform-eks stack provides:

- **Mixed OS Support**: Both Linux and Windows node groups
- **Linux Nodes**: For core DaemonSets, system components, and Linux workloads
- **Windows Nodes**: Specifically configured for Sitecore 10.4 CM/CD pods with Windows Server 2022 Core
- **Security**: KMS encryption, IRSA enabled, proper network security groups
- **ECR Integration**: Container registries for api, web, worker, cm, and cd components

### Windows Node Group Features

- **AMI Type**: WINDOWS_CORE_2022_x86_64 (Windows Server 2022)
- **Instance Types**: m5.2xlarge (optimized for Sitecore workloads)
- **Taints**: `os=windows:NoSchedule` to ensure proper pod scheduling
- **Labels**: `role=windows-workload`, `os=windows`
- **Scaling**: Environment-specific sizing (dev/qa: 2 desired, prod: 3 desired)

### DNS and TLS Management

The infrastructure includes automated DNS and TLS certificate management:

- **AWS Load Balancer Controller**: Provisions ALBs/NLBs for Kubernetes Ingress resources
- **cert-manager**: Automates SSL/TLS certificate provisioning using Let's Encrypt
- **external-dns**: Automatically manages Route 53 DNS records for services
- **IRSA Integration**: All controllers use IAM Roles for Service Accounts for secure AWS API access

#### Supported Domains
- **Development**: `dev.cluckn-bell.com`, `api.dev.cluckn-bell.com`
- **QA**: `qa.cluckn-bell.com`, `api.qa.cluckn-bell.com`
- **Production**: `cluckn-bell.com`, `api.cluckn-bell.com`

See `examples/ingress-examples.yaml` for complete Ingress configuration examples.

### Argo CD Access

Argo CD is configured with internal ALB access. The URLs are:
- **Development**: `https://argocd.dev.cluckn-bell.com`
- **QA**: `https://argocd.qa.cluckn-bell.com`
- **Production**: `https://argocd.cluckn-bell.com`

#### Access Methods:

1. **VPC Connectivity** (Recommended for production):
   - VPN connection to the VPC
   - Bastion host in public subnet
   - Direct VPC peering/Transit Gateway

2. **kubectl Port-Forward** (Development/Testing):
   ```bash
   # Configure kubectl first
   aws eks update-kubeconfig --region us-east-1 --name <environment>-cluckin-bell
   
   # Port-forward to Argo CD
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   
   # Access via browser at https://localhost:8080
   # Username: admin
   # Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

### GitHub App Configuration for Argo CD

To configure Argo CD with private repository access:

1. **Create GitHub App** in your organization with these permissions:
   - Repository permissions: Contents (read), Metadata (read), Pull requests (read)
   - Subscribe to: Push, Pull request events

2. **Configure Terraform variables:**
   ```bash
   # In your terraform.tfvars or environment variables
   github_app_id               = "123456"
   github_app_installation_id = "12345678"
   github_app_private_key      = "base64-encoded-private-key"
   ```

3. **Apply configuration:**
   ```bash
   terraform apply -var-file="env/dev.tfvars"
   ```

---

## Deployment Guide

### Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. kubectl installed for cluster management

### Infrastructure Deployment

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Plan Infrastructure** (per environment):
   ```bash
## Quick Start

### Deploy All Environments

Use the automated deployment script:

```bash
# Deploy all environments (dev, qa, prod)
./deploy-environments.sh

# Deploy a specific environment
./deploy-environments.sh dev
./deploy-environments.sh qa  
./deploy-environments.sh prod
```

### Manual Environment Deployment

```bash
# Deploy dev environment
cd stacks/environments/dev
terraform init
terraform plan
terraform apply

# Get cluster details
terraform output cluster_name
terraform output argocd_server_url
```

### ArgoCD Access

After deployment, access ArgoCD web interface:

```bash
# Update kubeconfig for the cluster
aws eks update-kubeconfig --region us-east-1 --name cb-dev-use1

# Get ArgoCD URL
cd stacks/environments/dev && terraform output argocd_server_url

# Get admin password
kubectl -n cluckin-bell get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## GitOps Workflow

1. **Platform Management**: Use this repository to manage infrastructure
2. **Application Deployment**: Use [`oscarmartinez0880/cluckin-bell`](https://github.com/oscarmartinez0880/cluckin-bell) repository
3. **Auto-Sync**: ArgoCD automatically syncs applications from git paths
4. **Environment Promotion**: Promote through environments via git

### Application Repository Structure

The application repository should contain:

```
oscarmartinez0880/cluckin-bell/
├── k8s/
│   ├── dev/       # Dev environment manifests
│   ├── qa/        # QA environment manifests
│   └── prod/      # Production environment manifests
└── ...
```

## Infrastructure Features

### Each Environment Includes

- **VPC**: Dedicated VPC with public/private subnets across 2 AZs
- **EKS Cluster**: Managed Kubernetes cluster with Linux node groups
- **Platform Controllers**:
  - AWS Load Balancer Controller for Ingress resources
  - cert-manager for automatic TLS certificate management
  - external-dns for Route 53 DNS automation
- **ArgoCD**: GitOps controller for application deployment
- **Security**: KMS encryption, IRSA roles, proper networking

### DNS and TLS Management

Automatic certificate management with environment-specific domains:
- **Dev**: `*.dev.cluckin-bell.com`
- **QA**: `*.qa.cluckin-bell.com` 
- **Prod**: `*.cluckin-bell.com`

### Resource Configuration by Environment

| Environment | Linux Nodes | Instance Types | VPC CIDR |
|-------------|-------------|----------------|----------|
| **dev** | 2 desired, max 5 | m5.large, m5.xlarge | 10.0.0.0/16 |
| **qa** | 3 desired, max 8 | m5.large, m5.xlarge | 10.1.0.0/16 |
| **prod** | 5 desired, max 15 | m5.xlarge, m5.2xlarge | 10.2.0.0/16 |

## Prerequisites

1. **AWS CLI** configured with appropriate IAM permissions
2. **Terraform** >= 1.0 installed
3. **kubectl** for Kubernetes cluster management
4. **Git** access to both repositories

## Account-Level Resources

Before deploying environments, ensure account-level resources are set up:

```bash
# Deploy account-level IAM roles and ECR repositories
cd terraform/accounts/devqa    # For dev/qa environments
terraform init && terraform apply

cd terraform/accounts/prod    # For production environment  
terraform init && terraform apply
```

This creates GitHub OIDC roles for CI/CD integration.

## Monitoring and Observability

### Backend Setup (S3 State Storage)

1. **Deploy S3 Backend Bootstrap Stack First:**
   ```bash
   cd stacks/s3-backend
   terraform init
   terraform plan -var-file="../../env/dev.tfvars"
   terraform apply -var-file="../../env/dev.tfvars"
   ```

2. **Configure Backend for Main Stack:**
   Copy the backend example and update with your account ID:
   ```bash
   cp backend.hcl.example backend.hcl
   # Edit backend.hcl to replace ACCOUNT_ID with your AWS account ID
   ```

3. **Migrate State to S3:**
   ```bash
   terraform init -backend-config=backend.hcl -migrate-state
   ```

### Deployment Order

1. **Bootstrap Stack**: Deploy first to create GitHub OIDC IAM roles
2. **S3 Backend Stack**: Create S3 bucket for Terraform state
3. **Network Stack**: Deploy VPC and networking resources
4. **Platform EKS Stack**: Deploy EKS cluster 
5. **Data Stack**: Deploy databases and storage
6. **Registry Observability Stack**: Deploy ECR and monitoring

- **ArgoCD Dashboard**: View application deployment status and sync health
- **AWS CloudWatch**: EKS cluster metrics and container logs
- **Kubernetes Events**: Real-time cluster events and warnings
- **Application Health**: ArgoCD health checks for deployed applications

## Security Features

- **Network Isolation**: Each environment has dedicated VPC
- **Encryption at Rest**: EKS secrets encrypted with KMS
- **IRSA**: IAM Roles for Service Accounts for secure AWS API access
- **TLS Automation**: Let's Encrypt certificates for all domains
- **GitOps Audit Trail**: All changes tracked in git history

## Version Constraints

- **Terraform**: >= 1.0
- **AWS Provider**: ~> 5.0
- **Kubernetes Provider**: ~> 2.20
- **Helm Provider**: ~> 2.0
- **EKS Module**: ~> 20.0
- **Kubernetes Version**: 1.29

## Troubleshooting

### Common Issues

1. **ArgoCD Sync Failures**: Check application repo structure and manifests
2. **Certificate Issues**: Verify Route 53 hosted zone configuration
3. **Load Balancer Issues**: Check security groups and subnet tags
4. **DNS Issues**: Verify external-dns permissions and configuration

### Useful Commands

```bash
# Check cluster status
kubectl get nodes

# Check platform controllers
kubectl get pods -n cluckin-bell

# Check ArgoCD applications
kubectl get applications -n cluckin-bell

# View ArgoCD logs
kubectl logs -n cluckin-bell deployment/argocd-server
```

## Support

For issues and questions:
1. Check the [environment-specific README](stacks/environments/README.md)
2. Review ArgoCD application status in the web interface
3. Check Terraform state and outputs
4. Review AWS CloudWatch logs for detailed error information

