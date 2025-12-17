# Cluckin Bell Infrastructure

This repository contains Terraform infrastructure as code for the Cluckin Bell application, providing multi-environment EKS clusters with GitOps using ArgoCD.

## Operating Model

The infrastructure follows a separation of concerns for better safety and clarity:

- **Terraform** manages foundational AWS resources (VPCs, IAM, Route53, ECR, WAF, endpoints)
- **eksctl** manages EKS cluster lifecycle (creation, upgrades, Kubernetes >= v1.34)
- **Argo CD / Helm** manages all in-cluster resources (controllers, applications)

> **Important**: EKS management in Terraform is **disabled by default** (`manage_eks = false`). Clusters should be created and managed using eksctl. See [docs/CLUSTERS_WITH_EKSCTL.md](docs/CLUSTERS_WITH_EKSCTL.md) for the complete workflow.

To opt-in to Terraform-managed EKS (not recommended), set `manage_eks = true` in your environment stack variables.

## Architecture Overview

### Two-Cluster Environment Model

The infrastructure supports a two-cluster environment model:

| Environment | Account | Cluster Name | Namespaces | Domain |
|-------------|---------|--------------|------------|--------|
| **Nonprod** | 264765154707 | cluckn-bell-nonprod | dev, qa | dev/qa.cluckn-bell.com |
| **Prod** | 346746763840 | cluckn-bell-prod | prod | cluckn-bell.com |

### GitOps Architecture

- **Platform Components** (Terraform-managed): VPC, IAM, Route53, ECR, WAF, VPC endpoints
- **EKS Clusters** (eksctl-managed): Cluster lifecycle, Kubernetes >= v1.34, node groups, add-ons
- **IRSA Roles** (Terraform post-cluster): IAM roles for service accounts after cluster creation
- **Controllers & Apps** (ArgoCD/Helm-managed): AWS LB Controller, external-dns, cert-manager, application workloads from [`oscarmartinez0880/cluckin-bell`](https://github.com/oscarmartinez0880/cluckin-bell)
- **Single Namespace Strategy**: All components deployed to `cluckin-bell` namespace per cluster

## Repository Structure

```
├── envs/                      # Environment-specific infrastructure  
│   ├── nonprod/              # Nonprod resources (account 264765154707)
│   │                         # Single cluster: cluckn-bell-nonprod (dev+qa namespaces)
│   └── prod/                 # Prod resources (account 346746763840)
│                             # Single cluster: cluckn-bell-prod (prod namespace)
├── stacks/                    # Terraform stacks
│   ├── environments/         # Per-environment EKS stacks (dev, qa, prod) - EKS disabled by default
│   ├── irsa-bootstrap/       # IRSA role creation (run after eksctl cluster creation)
│   └── ...
├── modules/                   # Consolidated Terraform modules
│   ├── vpc/                  # VPC with subnets, NAT gateways (single or multi)
│   ├── eks/                  # EKS cluster module (not used when manage_eks=false)
│   ├── irsa/                 # IRSA role module for service accounts
│   ├── dns-certs/            # Combined Route53 zones and ACM certificates
│   ├── k8s-controllers/      # Platform controllers (ALB, cert-manager, external-dns)
│   ├── monitoring/           # CloudWatch logs, metrics, and Container Insights
│   ├── argocd/               # ArgoCD GitOps setup
│   └── ...
├── eksctl/                    # eksctl cluster configurations (Kubernetes >= 1.34)
│   ├── devqa-cluster.yaml    # Nonprod cluster with dev/qa node groups
│   └── prod-cluster.yaml     # Prod cluster with prod node group
├── scripts/                   # Helper scripts
│   └── eks/                  # EKS management scripts
│       └── create-clusters.sh # Create/upgrade clusters with eksctl
├── terraform/accounts/       # Account-level resources (IAM, ECR)
│   ├── devqa/               # Dev/QA account resources
│   └── prod/                # Production account resources
└── docs/                    # Documentation
    ├── CLUSTERS_WITH_EKSCTL.md  # Complete guide for eksctl-based cluster management
    └── modules-matrix.md        # Complete modules reference
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

#### cert-manager IRSA for Route53 DNS01

The infrastructure provisions IRSA roles for cert-manager to perform DNS01 challenges with Route53:

- **Nonprod** (account 264765154707): Role `cluckn-bell-nonprod-cert-manager` with permissions for dev and qa hosted zones
- **Prod** (account 346746763840): Role `cluckn-bell-prod-cert-manager` with permissions for production hosted zone

**Kubernetes Configuration:**

To use cert-manager with the provisioned IRSA role, annotate the cert-manager ServiceAccount:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager
  namespace: cert-manager
  annotations:
    eks.amazonaws.com/role-arn: <cert_manager_role_arn_from_terraform_output>
```

The role ARN is available from Terraform outputs:
```bash
# Nonprod
cd envs/nonprod
terraform output cert_manager_role_arn

# Prod
cd envs/prod
terraform output cert_manager_role_arn
```

#### Karpenter - Just-in-Time Node Provisioning

Karpenter is available as an optional replacement for Cluster Autoscaler, providing more efficient and flexible node provisioning.

#### Benefits over Cluster Autoscaler

- **Faster provisioning**: Nodes are created in seconds, not minutes
- **Better bin-packing**: More efficient resource utilization
- **Pod-level scheduling**: Provisions nodes based on pending pod requirements
- **Multiple instance types**: Can provision different instance types based on workload needs
- **Spot instance support**: Native support for Spot instances with automatic fallback

#### Enabling Karpenter

Karpenter is disabled by default. To enable:

1. **Enable in Terraform**:
   ```bash
   cd envs/nonprod  # or envs/prod
   # Set enable_karpenter = true in your tfvars file
   terraform apply
   ```

2. **Apply NodePool and EC2NodeClass configurations**:
   ```bash
   # For nonprod
   kubectl apply -f charts/karpenter-config/nonprod/
   
   # For prod
   kubectl apply -f charts/karpenter-config/prod/
   ```

3. **Update the node IAM role name** in the EC2NodeClass YAML files to match your cluster's node role.

#### Migration from Cluster Autoscaler

When migrating from Cluster Autoscaler to Karpenter:

1. Install Karpenter (set `enable_karpenter = true`)
2. Apply NodePool and EC2NodeClass configurations
3. Monitor Karpenter provisioning new nodes for pending pods
4. Gradually scale down existing node groups managed by Cluster Autoscaler
5. Once stable, remove Cluster Autoscaler deployment
6. Remove `k8s.io/cluster-autoscaler/*` tags from node groups

**Note**: Both can run simultaneously during the migration period.

#### Configuration Files

- **Terraform Module**: `modules/karpenter/` - Deploys Karpenter controller with IAM roles
- **NodePool Configs**: `charts/karpenter-config/` - Defines node provisioning policies
- **Pod Identity**: Enabled by default for simplified IAM integration

See `charts/karpenter-config/README.md` for detailed configuration options.

## Alerting Infrastructure

The infrastructure includes a complete alerting pipeline for Prometheus Alertmanager:

#### Components

- **SNS Topic**: `alerts-nonprod` and `alerts-prod` for email and SMS notifications
- **Lambda Function**: `alertmanager-webhook-{env}` processes Alertmanager payloads
- **API Gateway**: HTTP API endpoint `/webhook` for Alertmanager webhook receiver
- **Secrets Manager**: `alertmanager/webhook-url-{env}` stores the webhook URL for GitOps reference

#### Alert Subscriptions

Each environment has two subscription types:

1. **Email**: `oscar21martinez88@gmail.com`
   - **Action Required**: Check your email inbox for an SNS subscription confirmation
   - Click the "Confirm subscription" link in the email from AWS Notifications
   - Until confirmed, email alerts will not be delivered

2. **SMS**: `+12298051449`
   - Auto-subscribed for most regions (including US)
   - No confirmation required

#### Webhook Configuration

The webhook URL is stored in AWS Secrets Manager and can be retrieved using:

```bash
# Nonprod
cd envs/nonprod
terraform output alerting_webhook_url

# Or from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id alertmanager/webhook-url-nonprod \
  --query SecretString --output text

# Prod
cd envs/prod
terraform output alerting_webhook_url

# Or from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id alertmanager/webhook-url-prod \
  --query SecretString --output text
```

#### Alertmanager Configuration

Configure Alertmanager to use the webhook receiver. If using External Secrets Operator, reference the secret:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: alertmanager-webhook
  namespace: monitoring
spec:
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: alertmanager-webhook
  data:
    - secretKey: webhook_url
      remoteRef:
        key: alertmanager/webhook-url-nonprod  # or prod
```

Then in your Alertmanager config:

```yaml
receivers:
  - name: 'webhook-receiver'
    webhook_configs:
      - url: '{{ .webhookUrl }}'
        send_resolved: true
```

#### Alert Message Format

The Lambda function formats alerts with the following information:
- Alert name and status (firing/resolved)
- Severity level
- Environment
- Instance/target
- Summary/description from annotations
- All labels for context

### Argo CD Access

Argo CD is configured with internal ALB access and admin authentication (no OIDC). The URLs are:
- **Development**: `https://argocd.dev.cluckn-bell.com`
- **QA**: `https://argocd.qa.cluckn-bell.com`
- **Production**: `https://argocd.cluckn-bell.com`

#### Access Methods:

1. **SSM Session Manager with Port Forwarding** (Recommended):
   
   **For Dev/QA environments (shared bastion):**
   ```bash
   # Get the dev bastion instance ID
   DEV_BASTION_ID=$(cd stacks/environments/dev && terraform output -raw bastion_instance_id)
   
   # Start SSM session with port forwarding to ArgoCD
   aws ssm start-session --target $DEV_BASTION_ID \
     --document-name AWS-StartPortForwardingSessionToRemoteHost \
     --parameters host="argocd.dev.cluckn-bell.com",portNumber="443",localPortNumber="8080"
   
   # For QA access via the same bastion (thanks to VPC peering and DNS association)
   aws ssm start-session --target $DEV_BASTION_ID \
     --document-name AWS-StartPortForwardingSessionToRemoteHost \
     --parameters host="argocd.qa.cluckn-bell.com",portNumber="443",localPortNumber="8081"
   
   # Access via browser at https://localhost:8080 (dev) or https://localhost:8081 (qa)
   ```
   
   **For Production environment (dedicated bastion):**
   ```bash
   # Get the prod bastion instance ID
   PROD_BASTION_ID=$(cd stacks/environments/prod && terraform output -raw bastion_instance_id)
   
   # Start SSM session with port forwarding to ArgoCD
   aws ssm start-session --target $PROD_BASTION_ID \
     --document-name AWS-StartPortForwardingSessionToRemoteHost \
     --parameters host="argocd.cluckn-bell.com",portNumber="443",localPortNumber="8082"
   
   # Access via browser at https://localhost:8082
   ```

2. **kubectl Port-Forward** (Alternative for development):
   ```bash
   # Configure kubectl first
   aws eks update-kubeconfig --region us-east-1 --name <environment>-cluckin-bell
   
   # Port-forward to Argo CD
   kubectl port-forward svc/argocd-server -n cluckin-bell 8080:80
   
   # Access via browser at http://localhost:8080
   ```

#### ArgoCD Authentication:
- **Username**: `admin`
- **Password**: Retrieved from Kubernetes secret:
  ```bash
  kubectl -n cluckin-bell get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
  ```

### SSM Bastion Hosts

The infrastructure includes SSM-managed bastion hosts for secure access:

- **Dev/QA Shared Bastion**: Deployed in the dev VPC, provides access to both dev and qa environments via VPC peering
- **Production Bastion**: Dedicated bastion in the prod VPC for production access only

**Prerequisites for SSM access:**
1. AWS CLI configured with appropriate permissions
2. Session Manager plugin installed:
   ```bash
   # Install on macOS
   brew install --cask session-manager-plugin
   
   # Install on Ubuntu/Debian
   curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
   sudo dpkg -i session-manager-plugin.deb
   ```

**Direct shell access via SSM:**
```bash
# Dev/QA bastion
DEV_BASTION_ID=$(cd stacks/environments/dev && terraform output -raw bastion_instance_id)
aws ssm start-session --target $DEV_BASTION_ID

# Production bastion
PROD_BASTION_ID=$(cd stacks/environments/prod && terraform output -raw bastion_instance_id)
aws ssm start-session --target $PROD_BASTION_ID
```

---

## GitOps and CodeCommit Integration

The infrastructure uses AWS CodeCommit as the GitOps source for ArgoCD, eliminating the need for GitHub App credentials or external Git providers.

### GitHub→CodeCommit Mirroring (Optional)

To automatically mirror changes from GitHub to CodeCommit, you can optionally enable Terraform-managed GitHub workflow:

1. **Configure GitHub provider** (optional):
   ```bash
   export GITHUB_TOKEN="your-repo-scoped-github-token"
   ```

2. **Enable workflow management**:
   ```bash
   # In terraform/accounts/devqa/terraform.tfvars
   manage_github_workflow = true
   github_repository_name = "cluckin-bell"
   ```

3. **Apply configuration**:
   ```bash
   cd terraform/accounts/devqa
   terraform apply
   ```

This creates a GitHub Actions workflow that uses OIDC to assume the CodeCommit mirroring role and pushes changes to the CodeCommit repository.

**Manual setup alternative**: If you prefer not to manage the workflow via Terraform, you can manually create the workflow file using the CodeCommit mirroring role ARN from the Terraform outputs.

---

## Deployment Guide

### Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. kubectl installed for cluster management
4. eksctl installed for EKS cluster management

---

## Quick Start with Makefile

The repository includes a standardized Makefile for common infrastructure operations. All commands support `ENV` (nonprod|prod) and `REGION` (default: us-east-1) variables.

### Basic Operations

```bash
# AWS SSO Login
make login-nonprod  # Login to nonprod account (cluckin-bell-qa)
make login-prod     # Login to prod account (cluckin-bell-prod)

# Terraform Operations
make tf-init ENV=nonprod                    # Initialize Terraform
make tf-plan ENV=nonprod REGION=us-east-1   # Plan changes
make tf-apply ENV=nonprod REGION=us-east-1  # Apply changes
make tf-destroy ENV=prod REGION=us-east-1   # Destroy infrastructure

# EKS Cluster Operations (via eksctl)
make eks-create ENV=nonprod REGION=us-east-1   # Create cluster
make eks-upgrade ENV=nonprod REGION=us-east-1  # Upgrade cluster
make eks-delete ENV=nonprod REGION=us-east-1   # Delete cluster

# View Outputs
make outputs ENV=nonprod  # Show Terraform outputs
```

### Disaster Recovery (DR)

To provision production infrastructure in an alternate region:

```bash
make dr-provision-prod REGION=us-west-2
```

This command will:
1. Login to prod account via AWS SSO
2. Apply Terraform configuration in the target region
3. Create EKS cluster in the target region

---

## One-Click Operations via GitHub Actions

The repository includes three GitHub Actions workflows for infrastructure management. All workflows use OIDC authentication and support manual triggering.

### 1. Infrastructure Terraform Workflow

**Workflow**: `.github/workflows/infra-terraform.yaml`

Manage Terraform infrastructure (VPC, IAM, DNS, etc.) with one click.

**Inputs**:
- **env**: nonprod or prod
- **action**: plan, apply, or destroy
- **region**: AWS region (default: us-east-1)

**Required Secrets**:
- `AWS_TERRAFORM_ROLE_ARN_QA`: OIDC role ARN for nonprod account
- `AWS_TERRAFORM_ROLE_ARN_PROD`: OIDC role ARN for prod account

**Example Usage**:
1. Go to Actions tab → "Infra Terraform (manual)"
2. Click "Run workflow"
3. Select environment, action, and region
4. Click "Run workflow"

### 2. eksctl Cluster Operations Workflow

**Workflow**: `.github/workflows/eksctl-cluster.yaml`

Manage EKS cluster lifecycle operations with one click.

**Inputs**:
- **env**: nonprod or prod
- **operation**: create, upgrade, or delete
- **region**: AWS region (default: us-east-1)

**Required Secrets**:
- `AWS_EKSCTL_ROLE_ARN_QA`: OIDC role ARN for nonprod account
- `AWS_EKSCTL_ROLE_ARN_PROD`: OIDC role ARN for prod account

**Example Usage**:
1. Go to Actions tab → "eksctl Cluster Ops (manual)"
2. Click "Run workflow"
3. Select environment, operation, and region
4. Click "Run workflow"

### 3. DR Launch Workflow

**Workflow**: `.github/workflows/dr-launch-prod.yaml`

Launch production infrastructure and EKS cluster in an alternate region for disaster recovery.

**Inputs**:
- **region**: Target region (default: us-west-2)

**Required Secrets**:
- `AWS_TERRAFORM_ROLE_ARN_PROD`: OIDC role ARN for prod account

**Example Usage**:
1. Go to Actions tab → "DR: Launch Prod in Alternate Region (manual)"
2. Click "Run workflow"
3. Enter target region (e.g., us-west-2)
4. Click "Run workflow"

### Setting Up GitHub Actions Secrets

To use the GitHub Actions workflows, configure the following repository secrets:

1. Go to Settings → Secrets and variables → Actions
2. Add the following secrets:
   - `AWS_TERRAFORM_ROLE_ARN_QA`: OIDC role ARN for nonprod (e.g., `arn:aws:iam::264765154707:role/github-oidc-terraform`)
   - `AWS_TERRAFORM_ROLE_ARN_PROD`: OIDC role ARN for prod (e.g., `arn:aws:iam::346746763840:role/github-oidc-terraform`)
   - `AWS_EKSCTL_ROLE_ARN_QA`: OIDC role ARN for nonprod eksctl operations
   - `AWS_EKSCTL_ROLE_ARN_PROD`: OIDC role ARN for prod eksctl operations

---

## Disaster Recovery Playbook

### Overview

The DR capability allows you to quickly stand up production infrastructure in an alternate AWS region in case of a regional outage or disaster.

### DR Architecture

- **Primary Region**: us-east-1 (default)
- **DR Region**: us-west-2 (or any AWS region)
- **Scope**: Full production stack (VPC, IAM, RDS, ECR, EKS cluster)
- **RTO Target**: < 1 hour (depending on EKS cluster creation time)

### DR Procedure

#### Option 1: Via Makefile (Local)

```bash
# Ensure you're authenticated
make login-prod

# Provision infrastructure and cluster in DR region
make dr-provision-prod REGION=us-west-2
```

#### Option 2: Via GitHub Actions (One-Click)

1. Navigate to Actions tab
2. Select "DR: Launch Prod in Alternate Region (manual)"
3. Click "Run workflow"
4. Enter target region (e.g., `us-west-2`)
5. Click "Run workflow"
6. Monitor workflow progress

#### Post-DR Steps

After infrastructure and cluster are provisioned:

1. **Update DNS**: Update Route53 records to point to new region
   ```bash
   # Get new load balancer endpoints
   make outputs ENV=prod
   ```

2. **Deploy Applications**: Use ArgoCD or Helm to deploy applications to new cluster
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name cluckn-bell-prod
   # Deploy applications via ArgoCD or manual apply
   ```

3. **Verify Services**: Test application endpoints and health checks

4. **Update Monitoring**: Configure CloudWatch dashboards for new region

#### DR Rollback

To return to primary region after incident is resolved:

```bash
# Deploy applications back to primary region
aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-prod

# Update DNS back to primary region

# Optional: Destroy DR infrastructure
make tf-destroy ENV=prod REGION=us-west-2
make eks-delete ENV=prod REGION=us-west-2
```

### DR Considerations

- **Data Replication**: Ensure RDS cross-region replication is configured if needed
- **Secrets Management**: Secrets Manager supports cross-region replication
- **ECR Replication**: Configure ECR replication rules for multi-region access
- **State Management**: Terraform state is in S3 with versioning enabled
- **Cost**: DR infrastructure incurs costs - consider using smaller instance types for standby

---

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
# Deploy nonprod environment (dev + qa)
cd envs/nonprod
terraform init
terraform plan
terraform apply

# Deploy prod environment
cd envs/prod
terraform init
terraform plan
terraform apply
```

### Post-Deployment Steps

#### 1. Confirm SNS Email Subscription

After applying the Terraform configuration, you **must** confirm the email subscription:

1. Check the inbox for `oscar21martinez88@gmail.com`
2. Look for an email from "AWS Notifications" with subject "AWS Notification - Subscription Confirmation"
3. Click the "Confirm subscription" link
4. You should see a confirmation page from AWS

**Important**: Email alerts will **not** be delivered until the subscription is confirmed.

SMS alerts to `+12298051449` are auto-confirmed and require no action.

#### 2. Retrieve Webhook URL and Role ARNs

```bash
# Nonprod
cd envs/nonprod
terraform output cert_manager_role_arn
terraform output alerting_webhook_url

# Prod
cd envs/prod
terraform output cert_manager_role_arn
terraform output alerting_webhook_url
```

#### 3. Configure Kubernetes Resources

Use the outputs to configure cert-manager and Alertmanager in your Kubernetes manifests or Helm values.

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
- **EKS Cluster**: Managed Kubernetes cluster with Linux node groups (1.33+)
- **Platform Controllers**:
  - AWS Load Balancer Controller for Ingress resources
  - cert-manager for automatic TLS certificate management
  - external-dns for Route 53 DNS automation
- **Karpenter** (Optional): Just-in-time node provisioning with Pod Identity support
- **ArgoCD**: GitOps controller for application deployment
- **Security**: KMS encryption, IRSA roles, EKS Pod Identity, proper networking

### DNS and TLS Management

Automatic certificate management with environment-specific domains:
- **Dev**: `*.dev.cluckin-bell.com`
- **QA**: `*.qa.cluckin-bell.com` 
- **Prod**: `*.cluckin-bell.com`

### Alerting and Email Delivery

SES SMTP is configured for Alertmanager email delivery:
- **SES Domain Identity**: `cluckn-bell.com` (verified in prod account)
- **SMTP Endpoint**: `email-smtp.us-east-1.amazonaws.com:587`
- **Sender Address**: `alerts@cluckn-bell.com`
- **Secrets Management**: SMTP credentials stored in AWS Secrets Manager per environment

See [SES SMTP Setup Guide](docs/SES_SMTP_SETUP.md) for complete configuration instructions.

### Resource Configuration by Environment

| Environment | Linux Nodes | Instance Types | VPC CIDR | Bastion Access |
|-------------|-------------|----------------|----------|----------------|
| **dev** | 2 desired, max 5 | m5.large, m5.xlarge | 10.0.0.0/16 | Shared dev/qa bastion |
| **qa** | 3 desired, max 8 | m5.large, m5.xlarge | 10.1.0.0/16 | Via dev bastion (VPC peering) |
| **prod** | 5 desired, max 15 | m5.xlarge, m5.2xlarge | 10.2.0.0/16 | Dedicated prod bastion |

**Bastion Configuration:**
- Instance Type: t3.micro (Amazon Linux 2023)
- Access Method: SSM Session Manager only
- Security: No inbound rules, private subnet deployment
- VPC Endpoints: SSM, SSMMessages, EC2Messages for connectivity

## Prerequisites

1. **AWS CLI** configured with appropriate IAM permissions
2. **Terraform** >= 1.0 installed
3. **kubectl** for Kubernetes cluster management
4. **Session Manager Plugin** for SSM access:
   ```bash
   # Install on macOS
   brew install --cask session-manager-plugin
   
   # Install on Ubuntu/Debian
   curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
   sudo dpkg -i session-manager-plugin.deb
   ```
5. **Git** access to repositories (CodeCommit via AWS CLI)

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

- **Zero-Trust Access**: SSM Session Manager provides secure access without SSH keys or public IPs
- **Network Isolation**: Each environment has dedicated VPC with private subnets
- **Bastion Hosts**: SSM-managed bastion instances for secure access to internal resources
- **VPC Endpoints**: SSM VPC endpoints enable Session Manager access without NAT Gateway dependency  
- **Network Segmentation**: VPC peering between dev/qa with controlled routing
- **Encryption at Rest**: EKS secrets encrypted with KMS
- **EKS Pod Identity**: Simplified IAM integration for Kubernetes workloads (enabled for Karpenter)
- **IRSA**: IAM Roles for Service Accounts for secure AWS API access (legacy, maintained for compatibility)
- **TLS Automation**: Let's Encrypt certificates for all domains
- **GitOps Audit Trail**: All changes tracked in CodeCommit git history
- **OIDC Authentication**: GitHub Actions use OIDC for secure, keyless CI/CD

### EKS Pod Identity vs IRSA

The infrastructure supports both EKS Pod Identity and IRSA for IAM integration:

**EKS Pod Identity** (Recommended for new workloads):
- Simpler setup - no OIDC provider configuration needed
- Managed by AWS EKS service
- Automatic credential rotation
- Enabled by default for Karpenter controller
- Requires `eks-pod-identity-agent` add-on (included in eksctl configs)

**IRSA** (Legacy, maintained for compatibility):
- Uses OIDC provider federation
- Requires service account annotations
- Still used for existing controllers (cert-manager, external-dns, etc.)
- Fully supported for backward compatibility

New deployments should prefer EKS Pod Identity where possible, while existing IRSA-based workloads continue to work without changes.

## Version Constraints

- **Terraform**: >= 1.0
- **AWS Provider**: ~> 5.0
- **Kubernetes Provider**: ~> 2.20
- **Helm Provider**: ~> 2.0
- **EKS Module**: ~> 20.0
- **Kubernetes Version**: 1.33 or newer

## Troubleshooting

### Common Issues

1. **ArgoCD Sync Failures**: Check application repo structure and manifests in CodeCommit
2. **Certificate Issues**: Verify Route 53 hosted zone configuration
3. **Load Balancer Issues**: Check security groups and subnet tags
4. **DNS Issues**: Verify external-dns permissions and configuration
5. **SSM Session Manager Issues**: 
   - Ensure Session Manager plugin is installed
   - Verify IAM permissions for SSM access
   - Check VPC endpoints are healthy
   - Confirm bastion instance is running and has SSM agent

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

# Check bastion instance status
aws ssm describe-instance-information --filters "Key=InstanceIds,Values=INSTANCE_ID"

# Test SSM connectivity
aws ssm start-session --target INSTANCE_ID

# Check VPC endpoints
aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=VPC_ID"
```

## Environments and Deployment

For comprehensive information about environment management and deployment procedures:

- **[Environment Guide](docs/ENVIRONMENTS.md)**: Detailed overview of account structure, environment configurations, technology versions, and resource scaling strategies
- **[Deployment Guide](docs/DEPLOYMENT.md)**: Step-by-step deployment instructions, SSO configuration, troubleshooting, and operational procedures
- **[k8s-controllers DevQA Guide](modules/k8s-controllers/README-devqa.md)**: Specific guidance for using the k8s-controllers module in DevQA shared cluster environments

### Quick Reference

| Environment | Account | Cluster | Domain | Deployment Command |
|-------------|---------|---------|--------|--------------------|
| **dev** | DevQA | cb-dev-use1 | dev.cluckin-bell.com | `./deploy-environments.sh dev` |
| **qa** | DevQA | cb-qa-use1 | qa.cluckin-bell.com | `./deploy-environments.sh qa` |
| **prod** | Production | cb-prod-use1 | cluckin-bell.com | `./deploy-environments.sh prod` |

### SSO Authentication

```bash
# DevQA account (dev/qa environments)
aws sso login --profile cluckin-bell-devqa
export AWS_PROFILE=cluckin-bell-devqa

# Production account
aws sso login --profile cluckin-bell-prod
export AWS_PROFILE=cluckin-bell-prod
```

### Provider Configuration Troubleshooting

If you encounter "Failed to construct REST client: no client config" errors:

1. **Verify AWS authentication**: `aws sts get-caller-identity`
2. **Configure providers in your calling module**: The k8s-controllers module requires properly configured kubernetes and helm providers (see [Provider Configuration](#providers) section above)
3. **Use two-phase deployment**: First deploy EKS cluster, then k8s-controllers
4. **Check provider configuration**: See [examples/providers/providers.tf.example](examples/providers/providers.tf.example)

See the [k8s-controllers README](modules/k8s-controllers/README.md#troubleshooting) for detailed troubleshooting steps.

## Support

For issues and questions:
1. Check the [environment-specific README](stacks/environments/README.md)
2. Review ArgoCD application status in the web interface
3. Check Terraform state and outputs
4. Review AWS CloudWatch logs for detailed error information

