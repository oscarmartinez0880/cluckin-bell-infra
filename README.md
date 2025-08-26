# Cluckin Bell Infrastructure

This repository contains the complete infrastructure-as-code for the Cluckin Bell Sitecore 10.4 application on AWS EKS, supporting dev, qa, and prod environments.

## Infrastructure Architecture

The infrastructure is organized into 5 Terraform stacks following a modular approach:

- **bootstrap**: GitHub OIDC IAM roles and foundational security resources
- **network**: VPC, subnets, security groups, and networking resources  
- **platform-eks**: EKS cluster, node groups, and Kubernetes platform resources
- **data**: RDS databases, Redis clusters, and data storage resources
- **registry-obsv**: ECR repositories and observability infrastructure

## Structure

- `stacks/{stack-name}/`: Terraform configurations for each infrastructure stack
- `env/`: Environment-specific Terraform variable files (dev.tfvars, qa.tfvars, prod.tfvars)
- `k8s/{dev,qa,prod}/`: Kubernetes manifests for each environment
- `helm/`: Helm values per environment and role
- `k8s-monitoring/`: Prometheus+Grafana monitoring stack and dashboards
- `.github/workflows/`: CI/CD workflows for infrastructure deployment

## Getting Started

### Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. kubectl installed for Kubernetes operations

### Deployment Order

1. **Bootstrap Stack**: Deploy first to create GitHub OIDC IAM roles
   ```bash
   cd stacks/bootstrap
   terraform init
   terraform plan -var-file="../../env/dev.tfvars"
   terraform apply -var-file="../../env/dev.tfvars"
   ```

2. **Network Stack**: Deploy VPC and networking resources
3. **Platform EKS Stack**: Deploy EKS cluster 
4. **Data Stack**: Deploy databases and storage
5. **Registry Observability Stack**: Deploy ECR and monitoring

### CI/CD

The repository includes automated Terraform workflows:

- **Pull Requests**: Runs `terraform plan` for validation
- **Branch Deployments**: 
  - `develop` → dev environment
  - `staging` → qa environment  
  - `main` → prod environment

Set the `AWS_TERRAFORM_ROLE_ARN` repository secret with an IAM role trusted by GitHub OIDC.

## Security

- All IAM roles follow least-privilege principles
- GitHub OIDC trust policies constrain access to specific repositories
- ECR permissions limited to cluckin-bell/* namespace
- Infrastructure changes require PR approval
- Security scanning with tfsec on all PRs

---

## Legacy Content

This repository was migrated from a Kubernetes-focused setup and retains the following structure for application deployment:

- `k8s/{dev,qa,prod}/`: All Kubernetes manifests for each environment
- `helm/`: Helm values per environment and role  
- `k8s-monitoring/`: Full Prometheus+Grafana monitoring stack and dashboards

### Application Deployment Quickstart

1. Apply infrastructure with the Terraform stacks above
2. Update secrets and values files with actual endpoints, ARNs, etc.
3. Deploy manifests & Helm releases per environment
4. Set up monitoring and dashboards