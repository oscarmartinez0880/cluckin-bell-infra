# Cluckin Bell Infrastructure

This repository contains the complete, production-grade Terraform infrastructure and Kubernetes setup for Sitecore 10.4 XP Scaled on AWS EKS, supporting dev, qa, and prod environments with Windows node support for Sitecore CM/CD workloads.

This repository contains the complete infrastructure-as-code for the Cluckin Bell Sitecore 10.4 application on AWS EKS, supporting dev, qa, and prod environments.

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
   # Development
   terraform plan -var-file="env/dev.tfvars"
   
   # QA
   terraform plan -var-file="env/qa.tfvars"
   
   # Production
   terraform plan -var-file="env/prod.tfvars"
   ```

3. **Apply Infrastructure**:
   ```bash
   terraform apply -var-file="env/dev.tfvars"
   ```

4. **Configure kubectl**:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name <environment>-cluckin-bell
   ```

5. **Verify DNS/TLS Controllers**:
   ```bash
   # Check AWS Load Balancer Controller
   kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
   
   # Check cert-manager
   kubectl get pods -n cert-manager
   kubectl get clusterissuers
   
   # Check external-dns
   kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns
   ```

### Sitecore CM/CD Pod Scheduling

For Sitecore CM and CD pods to run on Windows nodes, use the following configuration:

#### Required nodeSelector and tolerations:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sitecore-cm
spec:
  nodeSelector:
    kubernetes.io/os: windows
    role: windows-workload
  tolerations:
  - key: "os"
    operator: "Equal"
    value: "windows"
    effect: "NoSchedule"
  containers:
  - name: sitecore-cm
    image: your-ecr-repo/cm:latest
    # ... rest of container spec
```

#### Example Deployment for Sitecore CM:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sitecore-cm
  namespace: sitecore
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sitecore-cm
  template:
    metadata:
      labels:
        app: sitecore-cm
    spec:
      nodeSelector:
        kubernetes.io/os: windows
        role: windows-workload
      tolerations:
      - key: "os"
        operator: "Equal"
        value: "windows"
        effect: "NoSchedule"
      containers:
      - name: sitecore-cm
        image: <account-id>.dkr.ecr.us-east-1.amazonaws.com/dev-cluckin-bell-cm:latest
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "2Gi"
            cpu: "1000m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
```

---

## Environment Configuration

### Development (dev)
- **Windows Nodes**: 2 desired, max 6 (m5.2xlarge)
- **Linux Nodes**: 2 desired, max 5 (m5.large, m5.xlarge)
- **ECR Retention**: 10 days for untagged images

### QA (qa)
- **Windows Nodes**: 2 desired, max 6 (m5.2xlarge)
- **Linux Nodes**: 3 desired, max 8 (m5.large, m5.xlarge)
- **ECR Retention**: 10 days for untagged images

### Production (prod)
- **Windows Nodes**: 3 desired, max 6 (m5.2xlarge)
- **Linux Nodes**: 5 desired, max 15 (m5.xlarge, m5.2xlarge)
- **ECR Retention**: 30 days for untagged images

---

## Version Constraints

- **Terraform**: >= 1.0
- **AWS Provider**: ~> 5.0
- **Kubernetes Provider**: ~> 2.20
- **EKS Module**: ~> 20.0
- **Kubernetes**: 1.29 (configurable per environment)
- **Windows Server**: 2022 Core (WINDOWS_CORE_2022_x86_64)

---

## Security Considerations

- All EKS clusters use KMS encryption for secrets
- IRSA (IAM Roles for Service Accounts) enabled
- ECR repositories have image scanning enabled
- Windows nodes have appropriate security group rules for Windows services
- Node groups have minimal IAM permissions with ECR read-only access

---

## Monitoring and Observability

See `k8s-monitoring/` directory for:
- Prometheus configuration
- Grafana dashboards
- Windows-specific monitoring considerations

---

## CI/CD Integration

This repository includes GitHub Actions workflows for:
- **terraform-pr.yml**: Terraform plan on pull requests
- **terraform-dev.yml**: Deploy to development environment
- **terraform-qa.yml**: Deploy to QA environment
- **terraform-prod.yml**: Deploy to production environment

Set the `AWS_TERRAFORM_ROLE_ARN` repository secret for authentication.

---

## Troubleshooting

### Windows Pod Scheduling Issues

If Windows pods are not scheduling:

1. **Check node readiness**:
   ```bash
   kubectl get nodes -l kubernetes.io/os=windows
   ```

2. **Verify taints and tolerations**:
   ```bash
   kubectl describe node <windows-node-name>
   ```

3. **Check pod events**:
   ```bash
   kubectl describe pod <pod-name>
   ```

### Common Windows Node Issues

- **VPC CNI**: Ensure aws-node-windows DaemonSet is running
- **Container Runtime**: Windows containers require Windows Server 2022 base images
- **Resource Limits**: Windows containers typically require more memory than Linux equivalents

---

## Contributing

1. Create feature branch from main
2. Make changes and test locally
3. Submit pull request with Terraform plan output
4. Ensure all CI checks pass before merging
=======
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

