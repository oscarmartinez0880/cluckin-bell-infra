# Deployment Guide

This guide provides detailed instructions for deploying and managing the Cluckin Bell infrastructure across different environments.

## Prerequisites

### Required Tools

1. **AWS CLI v2**: For AWS authentication and EKS cluster management
2. **Terraform >= 1.0**: Infrastructure as Code engine
3. **kubectl**: Kubernetes command-line tool
4. **Session Manager Plugin**: For SSM bastion access

#### Installation Commands

```bash
# AWS CLI v2 (Linux)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform (Linux)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# kubectl (Linux)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Session Manager Plugin (Linux)
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb

# macOS alternatives using Homebrew
brew install awscli terraform kubectl
brew install --cask session-manager-plugin
```

## AWS SSO Configuration

### SSO Profile Setup

Configure AWS SSO profiles for each account:

#### DevQA Account Profile

```bash
aws configure sso --profile cluckin-bell-devqa
```

**Configuration Values:**
- **SSO start URL**: `https://d-1234567890.awsapps.com/start`
- **SSO region**: `us-east-1`
- **Account ID**: `123456789012`
- **Role name**: `AdministratorAccess`
- **CLI default client region**: `us-east-1`
- **CLI default output format**: `json`

#### Production Account Profile

```bash
aws configure sso --profile cluckin-bell-prod
```

**Configuration Values:**
- **SSO start URL**: `https://d-1234567890.awsapps.com/start`
- **SSO region**: `us-east-1`
- **Account ID**: `987654321098`
- **Role name**: `AdministratorAccess`
- **CLI default client region**: `us-east-1`
- **CLI default output format**: `json`

### SSO Authentication

Before running any Terraform commands, authenticate with the appropriate account:

```bash
# For DevQA environments (dev, qa)
aws sso login --profile cluckin-bell-devqa
export AWS_PROFILE=cluckin-bell-devqa

# For Production environment
aws sso login --profile cluckin-bell-prod
export AWS_PROFILE=cluckin-bell-prod

# Verify authentication
aws sts get-caller-identity
```

## Deployment Commands

### Environment-Specific Deployment

#### Development Environment

```bash
# Set AWS profile
export AWS_PROFILE=cluckin-bell-devqa

# Navigate to dev environment
cd stacks/environments/dev

# Initialize and deploy
terraform init
terraform plan -var-file="../../../env/dev.tfvars"
terraform apply -var-file="../../../env/dev.tfvars"

# Get outputs
terraform output cluster_name
terraform output argocd_server_url
```

#### QA Environment

```bash
# Set AWS profile
export AWS_PROFILE=cluckin-bell-devqa

# Navigate to qa environment
cd stacks/environments/qa

# Initialize and deploy
terraform init
terraform plan -var-file="../../../env/qa.tfvars"
terraform apply -var-file="../../../env/qa.tfvars"

# Get outputs
terraform output cluster_name
terraform output argocd_server_url
```

#### Production Environment

```bash
# Set AWS profile
export AWS_PROFILE=cluckin-bell-prod

# Navigate to prod environment
cd stacks/environments/prod

# Initialize and deploy
terraform init
terraform plan -var-file="../../../env/prod.tfvars"
terraform apply -var-file="../../../env/prod.tfvars"

# Get outputs
terraform output cluster_name
terraform output argocd_server_url
```

### Automated Multi-Environment Deployment

Use the deployment script for automated deployment across environments:

```bash
# Deploy all environments
./deploy-environments.sh

# Deploy specific environment
./deploy-environments.sh dev
./deploy-environments.sh qa
./deploy-environments.sh prod
```

## Two-Phase Deployment Strategy

When deploying a new environment from scratch, use a two-phase approach to avoid provider configuration issues:

### Phase 1: Core Infrastructure

```bash
# Deploy EKS cluster first
terraform apply -target="module.vpc" -target="module.eks"
```

### Phase 2: Kubernetes Controllers

```bash
# Deploy k8s-controllers after cluster is ready
terraform apply
```

This ensures the EKS cluster exists before the kubernetes and helm providers attempt to connect.

## External DNS Configuration

### DevQA Environment External DNS

In the DevQA environment, external-dns uses **zone ID filters** instead of domain filters to manage multiple domains:

```hcl
# DevQA configuration
domain_filter = ""  # Empty - rely on zone_id_filters
zone_id_filters = [
  "Z2FDTNDATAQYW2",  # dev.cluckin-bell.com
  "Z3G5CAV3H4YUZ3"   # qa.cluckin-bell.com
]
```

### Production Environment External DNS

Production uses a specific domain filter:

```hcl
# Production configuration
domain_filter = "cluckin-bell.com"
zone_id_filters = ["Z1D633PJN98FT9"]  # cluckin-bell.com
```

## Kubernetes Cluster Access

### Update Kubeconfig

After deploying an environment, update your kubeconfig to access the cluster:

```bash
# Development cluster
aws eks update-kubeconfig --region us-east-1 --name cb-dev-use1 --profile cluckin-bell-devqa

# QA cluster
aws eks update-kubeconfig --region us-east-1 --name cb-qa-use1 --profile cluckin-bell-devqa

# Production cluster
aws eks update-kubeconfig --region us-east-1 --name cb-prod-use1 --profile cluckin-bell-prod

# Verify access
kubectl get nodes
```

### Multiple Cluster Context Management

Manage multiple cluster contexts efficiently:

```bash
# List available contexts
kubectl config get-contexts

# Switch between clusters
kubectl config use-context arn:aws:eks:us-east-1:123456789012:cluster/cb-dev-use1
kubectl config use-context arn:aws:eks:us-east-1:123456789012:cluster/cb-qa-use1
kubectl config use-context arn:aws:eks:us-east-1:987654321098:cluster/cb-prod-use1

# Create friendly aliases
kubectl config rename-context arn:aws:eks:us-east-1:123456789012:cluster/cb-dev-use1 dev
kubectl config rename-context arn:aws:eks:us-east-1:123456789012:cluster/cb-qa-use1 qa
kubectl config rename-context arn:aws:eks:us-east-1:987654321098:cluster/cb-prod-use1 prod

# Use friendly names
kubectl config use-context dev
kubectl config use-context qa
kubectl config use-context prod
```

## ArgoCD Access and Management

### ArgoCD URL Access

Get the ArgoCD server URLs from Terraform outputs:

```bash
# Development
cd stacks/environments/dev
terraform output argocd_server_url
# Output: https://argocd.dev.cluckin-bell.com

# QA
cd stacks/environments/qa
terraform output argocd_server_url
# Output: https://argocd.qa.cluckin-bell.com

# Production
cd stacks/environments/prod
terraform output argocd_server_url
# Output: https://argocd.cluckin-bell.com
```

### ArgoCD Access via SSM Port Forwarding

#### DevQA Environments (Shared Bastion)

```bash
# Get the bastion instance ID (from dev stack)
DEV_BASTION_ID=$(cd stacks/environments/dev && terraform output -raw bastion_instance_id)

# Port forward to dev ArgoCD
aws ssm start-session --target $DEV_BASTION_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="argocd.dev.cluckin-bell.com",portNumber="443",localPortNumber="8080" \
  --profile cluckin-bell-devqa

# Port forward to qa ArgoCD (using same bastion via VPC peering)
aws ssm start-session --target $DEV_BASTION_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="argocd.qa.cluckin-bell.com",portNumber="443",localPortNumber="8081" \
  --profile cluckin-bell-devqa

# Access via browser
# Dev: https://localhost:8080
# QA: https://localhost:8081
```

#### Production Environment (Dedicated Bastion)

```bash
# Get the production bastion instance ID
PROD_BASTION_ID=$(cd stacks/environments/prod && terraform output -raw bastion_instance_id)

# Port forward to prod ArgoCD
aws ssm start-session --target $PROD_BASTION_ID \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host="argocd.cluckin-bell.com",portNumber="443",localPortNumber="8082" \
  --profile cluckin-bell-prod

# Access via browser: https://localhost:8082
```

### ArgoCD Authentication

#### Get Admin Password

```bash
# Set the correct kubectl context first
kubectl config use-context dev  # or qa, prod

# Get the admin password
kubectl -n cluckin-bell get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Login credentials:
# Username: admin
# Password: <output from above command>
```

#### Alternative: kubectl Port Forward

```bash
# Alternative access method using kubectl
kubectl config use-context dev
kubectl port-forward svc/argocd-server -n cluckin-bell 8080:80

# Access via browser: http://localhost:8080
```

## Application Deployment via ArgoCD

### Application Repository Structure

The application repository should follow this structure:

```
oscarmartinez0880/cluckin-bell/
├── k8s/
│   ├── dev/          # Development manifests
│   │   ├── app1/
│   │   └── app2/
│   ├── qa/           # QA manifests
│   │   ├── app1/
│   │   └── app2/
│   └── prod/         # Production manifests
│       ├── app1/
│       └── app2/
└── helm/             # Helm charts and values
    ├── app1/
    └── app2/
```

### ArgoCD Application Creation

Applications are automatically created by the infrastructure deployment. To manually create additional applications:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluckin-bell-app
  namespace: cluckin-bell
spec:
  project: default
  source:
    repoURL: https://github.com/oscarmartinez0880/cluckin-bell.git
    targetRevision: HEAD
    path: k8s/dev  # Change to qa or prod for other environments
  destination:
    server: https://kubernetes.default.svc
    namespace: cluckin-bell
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### Environment Promotion Workflow

1. **Development**: Auto-sync enabled for rapid iteration
2. **QA**: Manual sync for controlled testing
3. **Production**: Manual sync with approval process

```bash
# Promote to QA (manual sync)
kubectl config use-context qa
argocd app sync cluckin-bell-app

# Promote to Production (manual sync with approval)
kubectl config use-context prod
argocd app sync cluckin-bell-app
```

## Troubleshooting Common Deployment Issues

### Issue: "Failed to construct REST client: no client config"

**Cause**: Kubernetes/Helm providers cannot connect to EKS cluster

**Solutions**:
1. Verify AWS authentication:
   ```bash
   aws sts get-caller-identity --profile cluckin-bell-devqa
   ```

2. Use two-phase deployment for new clusters:
   ```bash
   terraform apply -target="module.eks"
   terraform apply
   ```

3. Check EKS cluster exists:
   ```bash
   aws eks describe-cluster --name <cluster-name> --region us-east-1
   ```

### Issue: SSO Session Expired

**Symptoms**: AWS API calls return authentication errors

**Solution**:
```bash
# Re-authenticate with SSO
aws sso login --profile cluckin-bell-devqa
export AWS_PROFILE=cluckin-bell-devqa
```

### Issue: Terraform State Lock

**Symptoms**: "Error acquiring the state lock"

**Solution**:
```bash
# Identify the lock
terraform force-unlock <lock-id>

# Or wait for the lock to expire (usually 20 minutes)
```

### Issue: ArgoCD Applications Not Syncing

**Symptoms**: Applications show "OutOfSync" status

**Solutions**:
1. Check repository access:
   ```bash
   kubectl logs -n cluckin-bell deployment/argocd-repo-server
   ```

2. Verify application configuration:
   ```bash
   kubectl get applications -n cluckin-bell -o yaml
   ```

3. Manual sync:
   ```bash
   argocd app sync <application-name>
   ```

### Issue: DNS Records Not Created

**Symptoms**: Ingress has no DNS records in Route 53

**Solutions**:
1. Check external-dns logs:
   ```bash
   kubectl logs -n kube-system deployment/external-dns
   ```

2. Verify zone ID filters:
   ```bash
   kubectl describe deployment external-dns -n kube-system
   ```

3. Check IAM permissions for Route 53 access

### Issue: Certificates Not Issued

**Symptoms**: TLS secrets not created or certificate status shows errors

**Solutions**:
1. Check cert-manager logs:
   ```bash
   kubectl logs -n kube-system deployment/cert-manager
   ```

2. Verify ClusterIssuer status:
   ```bash
   kubectl get clusterissuer
   kubectl describe clusterissuer letsencrypt-prod
   ```

3. Check DNS01 challenge permissions for Route 53

### Issue: EKS VPC CNI Addon Invalid Configuration

**Symptoms**: Terraform apply fails with "InvalidParameterException" when creating vpc-cni addon

**Cause**: Using unsupported `configuration_values` with env keys like `ENABLE_WINDOWS_IPAM`

**Solution**:
```bash
# Remove invalid configuration_values from vpc-cni addon configuration
# For Windows support, use Helm charts or DaemonSets instead of managed addon env vars
```

**Note**: The EKS CreateAddon API only supports specific configuration schema. Environment variables like `ENABLE_WINDOWS_IPAM` are not part of the supported vpc-cni addon configuration.

### Issue: IAM Role Creation Duplicate Tag Keys

**Symptoms**: Terraform fails with duplicate tag key errors during IAM role creation

**Cause**: AWS treats tag keys as case-insensitive (e.g., "Project" and "project" are considered duplicates)

**Solutions**:
1. **Standardize tag keys**: Use consistent TitleCase for all tag keys:
   ```hcl
   tags = {
     Project     = "cluckin-bell"
     Environment = "prod"
     ManagedBy   = "terraform"
   }
   ```

2. **Avoid Name in common tags**: Don't include `Name` in shared tag maps as many modules add it automatically

3. **Use terraform plan without -target**: Always run full plan/apply to avoid drift:
   ```bash
   # Don't use -target for routine deployments
   terraform plan  # Not: terraform plan -target=module.eks
   terraform apply
   ```

**Prevention**: Use the standardized tag structure from `locals/naming.tf` across all environments.

## Monitoring and Alerting

### CloudWatch Integration

Each environment automatically sends logs to CloudWatch:

- **EKS Control Plane Logs**: API server, audit, authenticator logs
- **Application Logs**: Container logs from all namespaces
- **Platform Logs**: AWS Load Balancer Controller, cert-manager, external-dns logs

### Viewing Logs

```bash
# View EKS control plane logs
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/cb-dev-use1"

# View application logs
aws logs describe-log-groups --log-group-name-prefix "/aws/eks/cb-dev-use1/cluster"

# Stream logs
aws logs tail /aws/eks/cb-dev-use1/cluster --follow
```

### Cluster Health Checks

```bash
# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# Check platform controllers
kubectl get pods -n kube-system | grep -E "(aws-load-balancer-controller|cert-manager|external-dns)"

# Check ArgoCD status
kubectl get pods -n cluckin-bell | grep argocd
```

## Backup and Disaster Recovery

### Terraform State Backup

Terraform state is automatically backed up to S3 with versioning enabled:

```bash
# List state versions
aws s3api list-object-versions --bucket cluckin-bell-terraform-state-<account-id> --prefix environments/

# Restore previous state version if needed
aws s3api get-object --bucket cluckin-bell-terraform-state-<account-id> --key environments/dev/terraform.tfstate --version-id <version-id> terraform.tfstate
```

### Kubernetes Configuration Backup

```bash
# Backup all Kubernetes resources
kubectl get all --all-namespaces -o yaml > cluster-backup-$(date +%Y%m%d).yaml

# Backup specific namespace
kubectl get all -n cluckin-bell -o yaml > cluckin-bell-backup-$(date +%Y%m%d).yaml
```

### Database Backup (if applicable)

```bash
# List RDS snapshots
aws rds describe-db-snapshots --db-instance-identifier cluckin-bell-db-dev

# Create manual snapshot
aws rds create-db-snapshot --db-instance-identifier cluckin-bell-db-prod --db-snapshot-identifier manual-backup-$(date +%Y%m%d)
```

## Security Best Practices

### IAM and Access Management

1. **Use SSO**: Always authenticate via AWS SSO, never use long-term access keys
2. **Principle of Least Privilege**: Grant minimal necessary permissions
3. **MFA Enforcement**: Enable MFA for all administrative accounts
4. **Regular Access Review**: Audit and remove unused access periodically

### Network Security

1. **Private Subnets**: All workloads run in private subnets
2. **Security Groups**: Restrictive security group rules
3. **VPC Flow Logs**: Enable for network traffic monitoring
4. **Bastion Access**: Use SSM Session Manager instead of SSH

### Secrets Management

1. **AWS Secrets Manager**: Store sensitive data in Secrets Manager
2. **Kubernetes Secrets**: Use for cluster-internal secrets
3. **Secret Rotation**: Implement automatic secret rotation where possible
4. **No Hardcoded Secrets**: Never commit secrets to git repositories

### Monitoring and Compliance

1. **CloudTrail**: Enable for all API call logging
2. **Config Rules**: Implement compliance monitoring
3. **Security Scanning**: Regular vulnerability scans of container images
4. **Log Aggregation**: Centralize logs for security analysis