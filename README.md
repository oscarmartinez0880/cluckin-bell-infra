# Cluckin Bell Infrastructure

This repository contains the complete, production-grade Terraform infrastructure and Kubernetes setup for Sitecore 10.4 XP Scaled on AWS EKS, supporting dev, qa, and prod environments with Windows node support for Sitecore CM/CD workloads.

---

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