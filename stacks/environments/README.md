# Environment-Specific EKS Infrastructure

This directory contains Terraform configurations for provisioning EKS clusters per environment (dev, qa, prod) with GitOps using ArgoCD.

## Architecture Overview

Each environment stack provisions:

1. **VPC** - Dedicated VPC with public/private subnets across 2 AZs
2. **EKS Cluster** - Named following convention `cb-{env}-use1`
3. **Platform Controllers** - AWS Load Balancer Controller, cert-manager, external-dns
4. **ArgoCD** - GitOps controller configured to sync from `oscarmartinez0880/cluckin-bell` repo
5. **Single Namespace** - `cluckin-bell` for both platform and app workloads

## Cluster Naming Convention

| Environment | Cluster Name | VPC CIDR | Git Path |
|-------------|--------------|----------|----------|
| dev | cb-dev-use1 | 10.0.0.0/16 | k8s/dev |
| qa | cb-qa-use1 | 10.1.0.0/16 | k8s/qa |
| prod | cb-prod-use1 | 10.2.0.0/16 | k8s/prod |

## Directory Structure

```
stacks/environments/
├── dev/
│   ├── main.tf        # EKS cluster + VPC + ArgoCD for dev
│   ├── variables.tf   # Environment-specific variables
│   └── outputs.tf     # Cluster endpoints and details
├── qa/
│   ├── main.tf        # EKS cluster + VPC + ArgoCD for qa
│   ├── variables.tf   # Environment-specific variables
│   └── outputs.tf     # Cluster endpoints and details
└── prod/
    ├── main.tf        # EKS cluster + VPC + ArgoCD for prod
    ├── variables.tf   # Environment-specific variables
    └── outputs.tf     # Cluster endpoints and details
```

## Deployment

### Deploy Single Environment

```bash
# Deploy dev environment
cd stacks/environments/dev
terraform init
terraform plan
terraform apply

# Deploy qa environment
cd stacks/environments/qa
terraform init
terraform plan
terraform apply

# Deploy prod environment
cd stacks/environments/prod
terraform init
terraform plan
terraform apply
```

### Deploy All Environments

Use the deployment script in the root directory:

```bash
# From the root of the repository
./deploy-environments.sh
```

## GitOps Configuration

Each environment's ArgoCD is configured to:

- **Git Repository**: `https://github.com/oscarmartinez0880/cluckin-bell.git`
- **Git Paths**: 
  - Dev: `k8s/dev`
  - QA: `k8s/qa` 
  - Prod: `k8s/prod`
- **Auto-Sync**: Enabled with automatic pruning and self-healing
- **Namespace**: All applications deployed to `cluckin-bell` namespace

## Platform vs Application Separation

- **Platform Components** (Terraform-managed):
  - AWS Load Balancer Controller
  - cert-manager + ClusterIssuers
  - external-dns
  - ArgoCD itself

- **Application Workloads** (ArgoCD-managed):
  - All application deployments via `oscarmartinez0880/cluckin-bell` repository
  - Deployed to `cluckin-bell` namespace

## Outputs

Each environment provides:

- `cluster_name` - EKS cluster name
- `cluster_endpoint` - Kubernetes API endpoint
- `vpc_id` - VPC identifier
- `namespace` - Application namespace (`cluckin-bell`)
- `argocd_server_url` - ArgoCD web interface URL

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. kubectl installed for cluster management
4. Appropriate IAM roles for EKS and platform controllers

## Security Features

- **Encryption**: EKS secrets encrypted at rest with KMS
- **IRSA**: IAM Roles for Service Accounts for secure AWS API access
- **Network Security**: Private subnets for worker nodes, public subnets for load balancers
- **TLS**: Automatic certificate management with Let's Encrypt

## Monitoring Access

After deployment, access ArgoCD:

```bash
# Get ArgoCD server URL
terraform output argocd_server_url

# Get admin password
kubectl -n cluckin-bell get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Cleanup

To destroy an environment:

```bash
cd stacks/environments/{env}
terraform destroy
```

**Note**: Destroying infrastructure will remove all resources including persistent data. Ensure you have backups if needed.