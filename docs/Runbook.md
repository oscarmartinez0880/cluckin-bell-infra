# Cluckin Bell Infrastructure Operations Runbook

This comprehensive runbook documents all operational procedures for managing the Cluckin Bell EKS multi-cluster environment, including one-click operations via Makefile and GitHub Actions, and disaster recovery procedures.

## Table of Contents

1. [Environment Overview](#environment-overview)
2. [Prerequisites](#prerequisites)
3. [Repository Variables and IAM OIDC Setup](#repository-variables-and-iam-oidc-setup)
4. [Makefile Operations](#makefile-operations)
5. [GitHub Actions Operations](#github-actions-operations)
6. [Disaster Recovery Procedures](#disaster-recovery-procedures)
7. [Validation and Verification](#validation-and-verification)
8. [Rollback Procedures](#rollback-procedures)
9. [Troubleshooting](#troubleshooting)

---

## Environment Overview

### Account Structure

| Environment | AWS Account ID | Cluster Name | Domain | Region (Primary) |
|-------------|---------------|--------------|--------|------------------|
| **Nonprod** | 264765154707 | cluckn-bell-nonprod | dev/qa.cluckn-bell.com | us-east-1 |
| **Prod** | 346746763840 | cluckn-bell-prod | cluckn-bell.com | us-east-1 |

### Technology Versions

- **Terraform**: 1.13.1 (specified in all workflows)
- **Kubernetes**: 1.33 (target), minimum 1.30 supported
- **eksctl**: Latest version (>= v1.34 recommended)
- **AWS Provider**: ~> 5.0
- **EKS Module**: ~> 20.0

### Cluster Specifications

#### Nonprod Cluster (cluckn-bell-nonprod)
- **VPC CIDR**: 10.60.0.0/16
- **Node Groups**:
  - `dev`: m7i.large, 1-5 nodes (2 desired), 50GB gp3, AL2023
  - `qa`: m7i.large, 1-8 nodes (3 desired), 50GB gp3, AL2023
- **CloudWatch Logs**: 7 days retention
- **Add-ons**: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, eks-pod-identity-agent

#### Prod Cluster (cluckn-bell-prod)
- **VPC CIDR**: 10.70.0.0/16
- **Node Groups**:
  - `prod`: m7i.xlarge, 2-15 nodes (5 desired), 100GB gp3, AL2023
- **CloudWatch Logs**: 90 days retention
- **Add-ons**: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, eks-pod-identity-agent

### Operating Model

The infrastructure follows a clear separation of concerns:

1. **Terraform**: Manages foundational AWS resources (VPCs, IAM, Route53, ECR, WAF, VPC endpoints)
2. **eksctl**: Manages EKS cluster lifecycle (creation, upgrades, Kubernetes >= 1.30)
3. **Argo CD / Helm**: Manages in-cluster resources (controllers, applications)

**Important**: EKS clusters are **NOT** managed by Terraform. All cluster lifecycle operations use eksctl. See [docs/CLUSTERS_WITH_EKSCTL.md](CLUSTERS_WITH_EKSCTL.md) for detailed rationale.

---

## Prerequisites

### Required Tools

Verify all tools are installed:

```bash
make check-tools
```

This checks for:
- AWS CLI
- eksctl (>= v1.34)
- kubectl
- helm
- terraform (1.13.1)

### AWS SSO Configuration

Configure AWS SSO profiles in `~/.aws/config`:

```ini
[profile cluckin-bell-qa]
sso_start_url = https://your-org.awsapps.com/start
sso_region = us-east-1
sso_account_id = 264765154707
sso_role_name = AdministratorAccess
region = us-east-1

[profile cluckin-bell-prod]
sso_start_url = https://your-org.awsapps.com/start
sso_region = us-east-1
sso_account_id = 346746763840
sso_role_name = AdministratorAccess
region = us-east-1
```

### Access Requirements

- AWS SSO access with appropriate permissions
- GitHub repository access for workflows
- VPN or network access if required

---

## Repository Variables and IAM OIDC Setup

### GitHub Repository Variables

For GitHub Actions workflows to authenticate with AWS, configure these repository variables using the ARNs output by Terraform.

#### Obtaining Role ARNs from Terraform

After applying Terraform in each environment, retrieve the role ARNs:

```bash
# Get nonprod role ARNs
cd envs/nonprod
terraform output github_actions_terraform_role_arn
terraform output github_actions_eksctl_role_arn
terraform output github_actions_ecr_push_role_arn

# Get prod role ARNs
cd envs/prod
terraform output github_actions_terraform_role_arn
terraform output github_actions_eksctl_role_arn
terraform output github_actions_ecr_push_role_arn
```

#### Repository Settings Location
Navigate to: **GitHub Repository** → **Settings** → **Secrets and variables** → **Actions** → **Variables**

#### Nonprod Environment Variables

| Variable Name | Value | Purpose |
|--------------|-------|---------|
| `AWS_TERRAFORM_ROLE_ARN_NONPROD` | From `terraform output` (GitHubActions-Terraform-nonprod) | Terraform deployment role for nonprod |
| `AWS_EKSCTL_ROLE_ARN_NONPROD` | From `terraform output` (GitHubActions-eksctl-nonprod) | eksctl role for nonprod |
| `AWS_ECR_PUSH_ROLE_ARN_NONPROD` | From `terraform output` (GitHubActions-ECRPush-nonprod) | ECR push role for nonprod |
| `AWS_REGION_NONPROD` | `us-east-1` | Default region for nonprod |
| `NONPROD_ACCOUNT_ID` | `264765154707` | Account ID for validation |

#### Prod Environment Variables

| Variable Name | Value | Purpose |
|--------------|-------|---------|
| `AWS_TERRAFORM_ROLE_ARN_PROD` | From `terraform output` (GitHubActions-Terraform-prod) | Terraform deployment role for prod |
| `AWS_EKSCTL_ROLE_ARN_PROD` | From `terraform output` (GitHubActions-eksctl-prod) | eksctl role for prod |
| `AWS_ECR_PUSH_ROLE_ARN_PROD` | From `terraform output` (GitHubActions-ECRPush-prod) | ECR push role for prod |
| `AWS_REGION_PROD` | `us-east-1` | Default region for prod |
| `PROD_ACCOUNT_ID` | `346746763840` | Account ID for validation |

### IAM OIDC Trust Relationships

The GitHub Actions workflows use OIDC to assume IAM roles without long-lived credentials. The roles are configured with trust policies that allow GitHub Actions from this repository.

#### IAM Role Trust Policy Example

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:oscarmartinez0880/cluckin-bell-infra:*"
        }
      }
    }
  ]
}
```

#### Required IAM Role Permissions

The deployment roles need permissions for:
- Terraform state access (S3, DynamoDB)
- VPC and networking resources
- IAM role and policy management
- EKS cluster management (via eksctl)
- Route53 DNS management
- ECR repository management
- CloudWatch logs and metrics
- Secrets Manager access

**Note**: These roles are now managed by Terraform in the environment stacks (`envs/nonprod` and `envs/prod`).

### OIDC Provider and Roles Setup

The GitHub OIDC provider and IAM roles are created automatically when applying Terraform in each environment:

```bash
# Deploy OIDC provider and roles for nonprod
cd envs/nonprod
terraform init
terraform apply

# Deploy OIDC provider and roles for prod
cd envs/prod
terraform init
terraform apply
```

This creates:
- GitHub OIDC identity provider in IAM (`token.actions.githubusercontent.com`)
- Three IAM roles per environment with trust relationships for GitHub Actions:
  - `GitHubActions-Terraform-{env}`: For infrastructure deployment
  - `GitHubActions-eksctl-{env}`: For cluster management
  - `GitHubActions-ECRPush-{env}`: For container image publishing
- Required permissions policies (AdministratorAccess for Terraform/eksctl, ECR PowerUser for ECR push)

---

## Makefile Operations

The repository includes a comprehensive Makefile for all operational tasks. All commands support environment and region overrides.

### Authentication

#### Login to AWS SSO

```bash
# Login to nonprod (DevQA account)
make login-nonprod

# Login to prod account
make login-prod
```

**What it does**:
- Initiates AWS SSO login flow
- Opens browser for authentication
- Caches credentials for the session

### Terraform Operations

#### Initialize Terraform

```bash
# Initialize for nonprod
make tf-init ENV=nonprod REGION=us-east-1

# Initialize for prod
make tf-init ENV=prod REGION=us-east-1
```

**What it does**:
- Initializes Terraform backend (S3 state)
- Downloads required providers
- Configures workspace

#### Plan Infrastructure Changes

```bash
# Plan changes for nonprod
make tf-plan ENV=nonprod REGION=us-east-1

# Plan changes for prod (always review carefully!)
make tf-plan ENV=prod REGION=us-east-1
```

**What it does**:
- Shows what resources will be created/modified/destroyed
- Validates configuration
- Outputs plan for review

**Best Practice**: Always run plan before apply to review changes.

#### Apply Infrastructure Changes

```bash
# Apply changes for nonprod
make tf-apply ENV=nonprod REGION=us-east-1

# Apply changes for prod
make tf-apply ENV=prod REGION=us-east-1
```

**What it does**:
- Creates/updates AWS resources via Terraform
- Updates VPCs, IAM roles, Route53, ECR, etc.
- Does NOT create/modify EKS clusters (use eksctl)

**Warning**: For production, always review the plan output before confirming apply.

#### Destroy Infrastructure

```bash
# Destroy resources (requires confirmation)
make tf-destroy ENV=nonprod REGION=us-east-1

# For production (use extreme caution!)
make tf-destroy ENV=prod REGION=us-east-1
```

**What it does**:
- Prompts for confirmation (type 'yes')
- Destroys all Terraform-managed resources
- Does NOT destroy eksctl-managed EKS clusters

**Warning**: Destructive operation. Ensure you understand the impact before proceeding.

### EKS Cluster Management

All EKS cluster lifecycle operations use eksctl, not Terraform.

#### Create EKS Cluster

```bash
# Create nonprod cluster
make eks-create-env ENV=nonprod REGION=us-east-1

# Create prod cluster
make eks-create-env ENV=prod REGION=us-east-1
```

**What it does**:
- Reads cluster config from `eksctl/devqa-cluster.yaml` or `eksctl/prod-cluster.yaml`
- Creates EKS control plane (K8s 1.33)
- Creates managed node groups with AL2023
- Enables OIDC provider for IRSA
- Installs core add-ons (vpc-cni, coredns, kube-proxy, ebs-csi-driver, pod-identity-agent)
- Configures CloudWatch logging

**Duration**: 15-20 minutes

**Prerequisites**: VPC and subnets must exist (run `make tf-apply` first)

**Note**: Update the VPC ID and subnet IDs in the eksctl YAML files before creating clusters. Get these from `make outputs ENV=nonprod`.

#### Upgrade EKS Cluster

```bash
# Upgrade nonprod cluster
make eks-upgrade ENV=nonprod

# Upgrade prod cluster (test in nonprod first!)
make eks-upgrade ENV=prod
```

**What it does**:
- Upgrades EKS control plane to next minor version
- Upgrades managed node groups
- Updates add-ons to compatible versions
- Validates cluster health

**Duration**: 30-45 minutes

**Best Practice**: Always test upgrades in nonprod first. Review AWS EKS upgrade documentation for version-specific breaking changes.

#### Delete EKS Cluster

```bash
# Delete cluster (requires confirmation)
make eks-delete ENV=nonprod

# For production (use extreme caution!)
make eks-delete ENV=prod
```

**What it does**:
- Prompts for confirmation (type 'yes')
- Deletes all node groups
- Deletes EKS control plane
- Removes associated resources (security groups, etc.)

**Duration**: 10-15 minutes

**Warning**: This is a destructive operation and cannot be undone.

### Infrastructure Outputs

#### View All Outputs

```bash
# View nonprod outputs
make outputs ENV=nonprod

# View prod outputs
make outputs ENV=prod
```

**What it provides**:
- VPC IDs and subnet IDs (needed for eksctl configs)
- RDS endpoints
- IAM role ARNs (IRSA roles, Karpenter, cert-manager)
- ECR repository URLs
- Route53 zone IDs
- Certificate ARNs
- Alerting webhook URLs

**Use Case**: Get values to populate eksctl configs or Kubernetes manifests.

### IRSA Bootstrap

After creating an EKS cluster, bootstrap IRSA (IAM Roles for Service Accounts) for platform controllers:

```bash
# Bootstrap IRSA for nonprod cluster
make irsa-nonprod

# Bootstrap IRSA for prod cluster
make irsa-prod
```

**What it does**:
- Retrieves OIDC issuer URL from the cluster
- Creates IAM roles for service accounts:
  - AWS Load Balancer Controller
  - external-dns
  - cert-manager
  - Cluster Autoscaler (if used)

**Prerequisites**: EKS cluster must exist (`make eks-create-env` completed)

---

## GitHub Actions Operations

The repository provides three GitHub Actions workflows for infrastructure operations via the web interface. These workflows use OIDC authentication (no credentials needed).

### 1. Infrastructure Terraform Workflow

**Workflow**: `.github/workflows/infra-terraform.yaml`

**Purpose**: Run Terraform operations (plan, apply, destroy) on infrastructure

**How to Use**:
1. Navigate to **Actions** → **Infrastructure Terraform**
2. Click **Run workflow**
3. Select inputs:
   - **Environment**: `nonprod` or `prod`
   - **Action**: `plan`, `apply`, or `destroy`
   - **Region**: Target AWS region (default: `us-east-1`)
4. Click **Run workflow**
5. Monitor progress in the workflow run page

**What it does**:
- Authenticates with AWS using OIDC (role ARNs from workflow config)
  - Nonprod: `arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa`
  - Prod: `arn:aws:iam::346746763840:role/cb-terraform-deploy-prod`
- Sets up Terraform 1.13.1
- Initializes Terraform with backend config
- Runs selected action (plan/apply/destroy)
- Displays outputs in workflow summary

**Typical Use Cases**:
- Initial infrastructure provisioning
- Apply configuration changes
- Plan changes before manual review
- Emergency infrastructure updates

**Duration**: 5-10 minutes for apply

### 2. EKS Cluster Management Workflow

**Workflow**: `.github/workflows/eksctl-cluster.yaml`

**Purpose**: Manage EKS cluster lifecycle (create, upgrade, delete)

**How to Use**:
1. Navigate to **Actions** → **EKS Cluster Management**
2. Click **Run workflow**
3. Select inputs:
   - **Environment**: `nonprod` or `prod`
   - **Operation**: `create`, `upgrade`, or `delete`
   - **Region**: Target AWS region (default: `us-east-1`)
4. Click **Run workflow**
5. Monitor progress in the workflow run page

**What it does**:
- Authenticates with AWS using OIDC
- Installs latest eksctl
- Runs selected operation:
  - **Create**: Creates cluster using `eksctl/{devqa|prod}-cluster.yaml`
  - **Upgrade**: Upgrades cluster to next K8s version
  - **Delete**: Deletes entire cluster and node groups
- Displays cluster info in workflow summary

**Typical Use Cases**:
- Create new clusters
- Upgrade Kubernetes version
- Remove old clusters

**Duration**:
- Create: 15-20 minutes
- Upgrade: 30-45 minutes
- Delete: 10-15 minutes

**Prerequisites for Create**:
- VPC and subnets must exist (run Infrastructure Terraform workflow first)
- Update eksctl YAML configs with actual VPC/subnet IDs

### 3. Disaster Recovery Launch Workflow

**Workflow**: `.github/workflows/dr-launch-prod.yaml`

**Purpose**: Quickly provision production infrastructure in an alternate region for disaster recovery

**How to Use**:
1. Navigate to **Actions** → **Disaster Recovery - Launch Prod**
2. Click **Run workflow**
3. Select inputs:
   - **Region**: DR region (choices: `us-west-2`, `us-west-1`, `eu-west-1`, `eu-central-1`, `ap-southeast-1`, `ap-northeast-1`)
4. Click **Run workflow**
5. Monitor progress in the workflow run page

**What it does**:
- Authenticates to prod account using OIDC
  - Role: `arn:aws:iam::346746763840:role/cb-terraform-deploy-prod`
- Sets up Terraform 1.13.1 and eksctl
- Runs Terraform to provision infrastructure in DR region:
  - VPC and networking
  - IAM roles
  - RDS (if configured)
  - ECR replication
  - Route53 records
- Creates EKS cluster using `eksctl/prod-cluster.yaml` in DR region
- Displays outputs and next steps in workflow summary

**Typical Use Cases**:
- Disaster recovery testing
- Regional failover preparation
- Multi-region deployment

**Duration**: 30-45 minutes

**Next Steps After Completion**:
The workflow summary will display:
1. Update DNS records to point to DR region
2. Bootstrap IRSA roles: `make irsa-prod REGION=<dr-region>`
3. Deploy applications via ArgoCD
4. Verify service health and monitoring
5. Update Route53 health checks

**Important Notes**:
- Always test DR workflows in nonprod before production
- Ensure ECR replication is configured
- Coordinate DNS cutover carefully
- Have a rollback plan ready

### Workflow Permissions

All workflows require these permissions (already configured):

```yaml
permissions:
  id-token: write    # Required for OIDC authentication
  contents: read     # Required to checkout code
```

### Monitoring Workflow Runs

- View all runs: **Actions** tab in GitHub
- Real-time logs: Click on a running workflow
- Artifacts: Download if workflow produces outputs
- Re-run: Click "Re-run jobs" if a workflow fails

---

## Disaster Recovery Procedures

This section covers comprehensive disaster recovery (DR) procedures for launching production infrastructure in an alternate region.

### DR Architecture Overview

- **Primary Region**: us-east-1 (default production)
- **DR Regions**: Any supported AWS region (us-west-2, eu-west-1, etc.)
- **RTO Target**: < 4 hours for full environment
- **RPO Target**: Based on RDS backup schedule and ECR replication lag

### DR Strategy

1. **Infrastructure as Code**: All infrastructure defined in Terraform, enabling rapid provisioning
2. **EKS Clusters**: eksctl configs enable identical cluster creation in any region
3. **Data Replication**: 
   - ECR images replicated across regions
   - RDS Multi-AZ for primary region HA
   - Secrets replicated via Terraform or Secrets Manager replication
4. **DNS Failover**: Route53 health checks and failover routing policies

### DR Provisioning Options

Choose one of three methods based on your needs:

#### Option 1: GitHub Actions (Recommended for Remote Teams)

**Advantages**: 
- No local dependencies
- Fully audited
- Easy to trigger from anywhere
- Built-in logging and notifications

**Steps**:
1. Navigate to **Actions** → **Disaster Recovery - Launch Prod**
2. Click **Run workflow**
3. Select DR region (e.g., `us-west-2`)
4. Click **Run workflow**
5. Monitor workflow progress (~30-45 minutes)
6. Follow post-provisioning steps displayed in workflow summary

#### Option 2: Makefile (Recommended for Local Control)

**Advantages**:
- More control over process
- Can pause between steps
- Interactive confirmations
- Good for DR testing

**Steps**:

```bash
# One-command DR provisioning with interactive prompts
make dr-provision-prod REGION=us-west-2
```

**The command will**:
1. Prompt for confirmation before starting
2. Login to prod account via AWS SSO
3. Initialize Terraform backend for DR region
4. Show Terraform plan for review
5. Prompt for apply confirmation
6. Apply Terraform to create infrastructure
7. Create EKS cluster via eksctl
8. Display completion status and next steps

**Duration**: 30-45 minutes

#### Option 3: Manual Steps (Recommended for Troubleshooting)

**Advantages**:
- Complete control
- Better for diagnosing issues
- Step-by-step visibility

**Steps**:

```bash
# Step 1: Login to prod account
make login-prod

# Step 2: Navigate to prod environment
cd envs/prod

# Step 3: Initialize Terraform
terraform init -backend-config=backend.hcl

# Step 4: Plan infrastructure for DR region
terraform plan -var="aws_region=us-west-2"

# Review the plan carefully before proceeding

# Step 5: Apply infrastructure
terraform apply -var="aws_region=us-west-2"

# Step 6: Return to repository root
cd ../..

# Step 7: Create EKS cluster in DR region
AWS_PROFILE=cluckin-bell-prod eksctl create cluster \
  -f eksctl/prod-cluster.yaml \
  --region us-west-2

# Step 8: Bootstrap IRSA roles
make irsa-prod REGION=us-west-2

# Step 9: Verify outputs
make outputs ENV=prod
```

**Duration**: 45-60 minutes

### Post-DR Provisioning Steps

After infrastructure is provisioned in DR region, complete these steps:

#### 1. Verify Infrastructure

```bash
# Check EKS cluster status
aws eks describe-cluster \
  --name cluckn-bell-prod \
  --region us-west-2 \
  --profile cluckin-bell-prod

# Check node groups
aws eks list-nodegroups \
  --cluster-name cluckn-bell-prod \
  --region us-west-2 \
  --profile cluckin-bell-prod

# Check RDS instances (if applicable)
aws rds describe-db-instances \
  --region us-west-2 \
  --profile cluckin-bell-prod
```

#### 2. Configure kubectl

```bash
# Update kubeconfig for DR cluster
aws eks update-kubeconfig \
  --name cluckn-bell-prod \
  --region us-west-2 \
  --profile cluckin-bell-prod

# Verify node health
kubectl get nodes
kubectl get nodes -o wide
```

#### 3. Bootstrap IRSA Roles

```bash
# Create IAM roles for service accounts in DR cluster
make irsa-prod REGION=us-west-2
```

**What this creates**:
- AWS Load Balancer Controller role
- external-dns role
- cert-manager role
- Cluster Autoscaler role (if used)

#### 4. Deploy Platform Components

```bash
# Deploy core platform controllers via Helm/ArgoCD
# This should be automated via your GitOps setup

# Verify controllers are running
kubectl get pods -n cluckin-bell
kubectl get pods -n kube-system

# Check for any issues
kubectl get events --all-namespaces --sort-by='.lastTimestamp'
```

#### 5. Restore Database (if needed)

```bash
# Restore RDS from latest snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier cluckin-bell-prod-dr \
  --db-snapshot-identifier <latest-snapshot-id> \
  --region us-west-2 \
  --profile cluckin-bell-prod

# Or restore from cross-region replica
# (if configured for synchronous replication)

# Update application connection strings via Kubernetes secrets
kubectl edit secret -n cluckin-bell app-database-connection
```

#### 6. ECR Image Replication

**If ECR replication is configured** (recommended):
- Images are automatically replicated across regions
- No manual action needed

**If manual replication is required**:

```bash
# List images in primary region
aws ecr describe-images \
  --repository-name cluckin-bell-app \
  --region us-east-1 \
  --profile cluckin-bell-prod

# Pull, tag, and push to DR region
# (Use ECR replication configuration instead - this is for reference only)
```

**To configure ECR replication** (do this before DR event):

```bash
# Create replication configuration
aws ecr put-replication-configuration \
  --replication-configuration file://ecr-replication.json \
  --region us-east-1 \
  --profile cluckin-bell-prod
```

`ecr-replication.json`:
```json
{
  "rules": [
    {
      "destinations": [
        {
          "region": "us-west-2",
          "registryId": "346746763840"
        }
      ],
      "repositoryFilters": [
        {
          "filter": "cluckin-bell-*",
          "filterType": "PREFIX_MATCH"
        }
      ]
    }
  ]
}
```

#### 7. Secrets Replication

**Option A: AWS Secrets Manager Replication** (recommended)

```bash
# Enable replication for critical secrets
aws secretsmanager replicate-secret-to-regions \
  --secret-id prod/database/password \
  --add-replica-regions Region=us-west-2 \
  --region us-east-1 \
  --profile cluckin-bell-prod

# Verify replication
aws secretsmanager describe-secret \
  --secret-id prod/database/password \
  --region us-west-2 \
  --profile cluckin-bell-prod
```

**Option B: Manual Secret Recreation**

```bash
# Export secrets from primary region (secure this output!)
aws secretsmanager get-secret-value \
  --secret-id prod/database/password \
  --region us-east-1 \
  --profile cluckin-bell-prod

# Create in DR region
aws secretsmanager create-secret \
  --name prod/database/password \
  --secret-string "$(cat secret-value.txt)" \
  --region us-west-2 \
  --profile cluckin-bell-prod
```

#### 8. Deploy Applications

```bash
# Deploy applications via ArgoCD
kubectl apply -f kubernetes/argocd/applications/

# Or trigger ArgoCD sync
kubectl patch app cluckin-bell-app \
  -n cluckin-bell \
  -p '{"operation":{"sync":{"syncStrategy":{"hook":{}}}}}' \
  --type merge

# Monitor deployment status
kubectl get applications -n cluckin-bell
kubectl get pods -n cluckin-bell
```

#### 9. DNS Cutover (Route53 Failover)

**Option A: Weighted Routing (Gradual Cutover)**

```bash
# Update Route53 to send 10% traffic to DR region
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://dns-weighted-cutover.json \
  --profile cluckin-bell-prod
```

`dns-weighted-cutover.json`:
```json
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "cluckn-bell.com",
        "Type": "A",
        "SetIdentifier": "DR-Region",
        "Weight": 10,
        "AliasTarget": {
          "HostedZoneId": "<dr-alb-hosted-zone-id>",
          "DNSName": "<dr-alb-dns-name>",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
```

**Gradually increase weight** (10% → 25% → 50% → 100%) while monitoring metrics.

**Option B: Failover Routing (Immediate Cutover)**

```bash
# Update Route53 to use failover routing
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://dns-failover.json \
  --profile cluckin-bell-prod
```

`dns-failover.json`:
```json
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "cluckn-bell.com",
        "Type": "A",
        "SetIdentifier": "Primary",
        "Failover": "PRIMARY",
        "AliasTarget": {
          "HostedZoneId": "<primary-alb-hosted-zone-id>",
          "DNSName": "<primary-alb-dns-name>",
          "EvaluateTargetHealth": true
        }
      }
    },
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "cluckn-bell.com",
        "Type": "A",
        "SetIdentifier": "Secondary",
        "Failover": "SECONDARY",
        "AliasTarget": {
          "HostedZoneId": "<dr-alb-hosted-zone-id>",
          "DNSName": "<dr-alb-dns-name>",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
```

**Option C: Simple Record Update (Fastest)**

```bash
# Get DR region ALB DNS name
ALB_DNS=$(kubectl get ingress -n cluckin-bell cluckin-bell-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Update A record to point to DR region
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://dns-update.json \
  --profile cluckin-bell-prod
```

#### 10. Monitoring and Validation

After cutover, continuously monitor:

```bash
# Check application health
kubectl get pods -n cluckin-bell
kubectl top nodes
kubectl top pods -n cluckin-bell

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name cluster_failed_node_count \
  --dimensions Name=ClusterName,Value=cluckn-bell-prod \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average \
  --region us-west-2 \
  --profile cluckin-bell-prod

# Test application endpoints
curl -I https://cluckn-bell.com
curl -I https://api.cluckn-bell.com

# Check Prometheus/Grafana dashboards
kubectl port-forward -n cluckin-bell svc/prometheus-server 9090:80
kubectl port-forward -n cluckin-bell svc/grafana 3000:80
```

### DR Testing Recommendations

- **Quarterly**: Test DR provisioning in alternate region (use separate AWS account if available)
- **Semi-Annually**: Full DR failover test with application traffic
- **Document**: Update runbook with lessons learned after each test
- **Automate**: Consider Route53 health checks for automatic failover

### RDS Multi-AZ for High Availability

For production databases, ensure Multi-AZ is enabled:

```hcl
# In your RDS Terraform module configuration (envs/prod/)
module "rds_prod" {
  source = "../../modules/rds"
  
  multi_az       = true      # Enable Multi-AZ for HA
  storage_type   = "gp3"     # Use gp3 for better performance
  backup_retention_period = 30
  
  # Other configuration...
}
```

**Multi-AZ provides**:
- ✅ Automatic failover to standby in another AZ
- ✅ RTO of 1-2 minutes for database failover
- ✅ Synchronous replication to standby
- ✅ No data loss on failover

**For cross-region DR**, use:
- RDS snapshots copied to DR region (automated)
- Or Read Replicas in DR region (for faster failover)

---

## Validation and Verification

After any infrastructure change, perform these validations:

### 1. Terraform Validation

```bash
# Verify Terraform state is consistent
cd envs/nonprod  # or envs/prod
terraform plan

# Should show "No changes. Your infrastructure matches the configuration."
```

### 2. EKS Cluster Health

```bash
# Check cluster status
aws eks describe-cluster \
  --name cluckn-bell-nonprod \
  --region us-east-1 \
  --profile cluckin-bell-qa \
  --query 'cluster.status'

# Should return: "ACTIVE"

# Check node health
kubectl get nodes
kubectl get nodes -o wide

# All nodes should be "Ready"

# Check system pods
kubectl get pods -n kube-system
kubectl get pods -n cluckin-bell

# All pods should be "Running" or "Completed"
```

### 3. Platform Controllers

```bash
# Verify AWS Load Balancer Controller
kubectl get deployment -n cluckin-bell aws-load-balancer-controller
kubectl logs -n cluckin-bell deployment/aws-load-balancer-controller

# Verify external-dns
kubectl get deployment -n cluckin-bell external-dns
kubectl logs -n cluckin-bell deployment/external-dns

# Verify cert-manager
kubectl get deployment -n cluckin-bell cert-manager
kubectl get certificates -n cluckin-bell
```

### 4. Application Health

```bash
# Check application deployments
kubectl get deployments -n cluckin-bell
kubectl get pods -n cluckin-bell
kubectl get ingress -n cluckin-bell

# Test endpoints
curl -I https://dev.cluckn-bell.com
curl -I https://qa.cluckn-bell.com
curl -I https://cluckn-bell.com  # prod
```

### 5. DNS and TLS

```bash
# Verify DNS records
dig dev.cluckn-bell.com
dig qa.cluckn-bell.com
dig cluckn-bell.com

# Verify TLS certificates
echo | openssl s_client -connect dev.cluckn-bell.com:443 -servername dev.cluckn-bell.com 2>/dev/null | openssl x509 -noout -dates

# Check cert-manager certificates
kubectl get certificates -n cluckin-bell
kubectl describe certificate <cert-name> -n cluckin-bell
```

### 6. Monitoring and Alerting

```bash
# Check CloudWatch log groups
aws logs describe-log-groups \
  --log-group-name-prefix /aws/eks/cluckn-bell \
  --region us-east-1

# Check alerting webhook
cd envs/nonprod  # or envs/prod
terraform output alerting_webhook_url

# Test Prometheus/Grafana access
kubectl port-forward -n cluckin-bell svc/prometheus-server 9090:80 &
curl -I http://localhost:9090

kubectl port-forward -n cluckin-bell svc/grafana 3000:80 &
curl -I http://localhost:3000
```

---

## Rollback Procedures

If a deployment or change causes issues, follow these rollback procedures:

### Rollback Terraform Changes

```bash
# If Terraform apply introduced issues

# Step 1: Identify the last known good state
cd envs/nonprod  # or envs/prod
terraform state list

# Step 2: Revert to previous Terraform code
git log --oneline  # Find commit hash of last good version
git checkout <commit-hash> -- .

# Step 3: Plan and apply revert
terraform plan
terraform apply

# OR: Use Terraform state rollback (if state was backed up)
# (This requires manual state manipulation - use with caution)
```

### Rollback EKS Cluster Changes

```bash
# If eksctl upgrade caused issues

# Kubernetes version cannot be downgraded
# Options:
# 1. Fix forward by applying patches/workarounds
# 2. Restore from backup (recreate cluster)

# For node group changes:
eksctl scale nodegroup \
  --cluster=cluckn-bell-nonprod \
  --name=dev \
  --nodes=<previous-desired-count> \
  --region=us-east-1

# For add-on issues:
# Reinstall previous add-on version via eksctl update addon
```

### Rollback Application Deployments

```bash
# Rollback via kubectl
kubectl rollout undo deployment/<deployment-name> -n cluckin-bell

# Or rollback via ArgoCD
kubectl patch app <app-name> \
  -n cluckin-bell \
  -p '{"spec":{"source":{"targetRevision":"<previous-commit-hash>"}}}' \
  --type merge

# Sync to apply rollback
kubectl patch app <app-name> \
  -n cluckin-bell \
  -p '{"operation":{"sync":{"syncStrategy":{"hook":{}}}}}' \
  --type merge
```

### Rollback DNS Changes

```bash
# Revert Route53 records to previous values
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://dns-rollback.json \
  --profile cluckin-bell-prod

# Check DNS propagation
dig cluckn-bell.com
nslookup cluckn-bell.com 8.8.8.8  # Use Google DNS to verify
```

### Emergency DR Rollback

If DR activation fails or needs to be reversed:

```bash
# 1. DO NOT destroy DR infrastructure
# Keep it for investigation and future testing

# 2. Update DNS to point back to primary region
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch file://dns-primary.json \
  --profile cluckin-bell-prod

# 3. Verify primary region health
kubectl get nodes --context=primary-cluster
kubectl get pods -n cluckin-bell --context=primary-cluster

# 4. Drain traffic from DR region
# (DNS change should handle this automatically)

# 5. Monitor and verify
# Check application metrics, logs, and user reports
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: AWS SSO Login Fails

**Symptoms**:
- `make login-nonprod` or `make login-prod` fails
- Error: "Unable to locate credentials"

**Solution**:
```bash
# Verify SSO configuration
aws configure list-profiles

# Check SSO status
aws sso login --profile cluckin-bell-qa

# If SSO session expired, re-login
aws sso logout
aws sso login --profile cluckin-bell-qa
```

#### Issue: Terraform Init Fails

**Symptoms**:
- `make tf-init` fails
- Error: "Error loading state: AccessDenied"

**Solution**:
```bash
# Ensure you're logged in to correct account
aws sts get-caller-identity

# Check backend configuration
cd envs/nonprod
cat backend.hcl

# Verify S3 bucket exists and you have access
aws s3 ls s3://<backend-bucket-name>
```

#### Issue: eksctl Create Cluster Fails

**Symptoms**:
- `make eks-create-env` fails
- Error: "subnet not found" or "VPC not found"

**Solution**:
```bash
# Step 1: Ensure VPC and subnets exist
cd envs/nonprod
terraform output vpc_id
terraform output private_subnet_ids

# Step 2: Update eksctl YAML with correct IDs
vim eksctl/devqa-cluster.yaml
# Update vpc.id and vpc.subnets.private entries

# Step 3: Retry cluster creation
make eks-create-env ENV=nonprod REGION=us-east-1
```

#### Issue: IRSA Bootstrap Fails

**Symptoms**:
- `make irsa-nonprod` fails
- Error: "OIDC issuer URL not found"

**Solution**:
```bash
# Ensure cluster exists and is active
aws eks describe-cluster \
  --name cluckn-bell-nonprod \
  --region us-east-1 \
  --profile cluckin-bell-qa

# Manually get OIDC issuer URL
OIDC_URL=$(aws eks describe-cluster \
  --name cluckn-bell-nonprod \
  --region us-east-1 \
  --profile cluckin-bell-qa \
  --query 'cluster.identity.oidc.issuer' \
  --output text)

echo $OIDC_URL

# If OIDC URL exists, retry
make irsa-nonprod
```

#### Issue: GitHub Actions Workflow Fails

**Symptoms**:
- Workflow fails with "Unable to assume role"
- Error: "AccessDenied"

**Solution**:
```bash
# Step 1: Verify OIDC provider exists in AWS account
aws iam list-open-id-connect-providers

# Should show: token.actions.githubusercontent.com

# Step 2: Verify IAM role trust policy
aws iam get-role --role-name cb-terraform-deploy-devqa
aws iam get-role --role-name cb-terraform-deploy-prod

# Step 3: Verify role ARN in workflow matches
# Check .github/workflows/infra-terraform.yaml
# role-to-assume: arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa

# Step 4: Re-deploy OIDC provider if needed
cd terraform/accounts/devqa
terraform apply
```

#### Issue: DNS Not Resolving

**Symptoms**:
- Applications not accessible via domain name
- `dig` or `nslookup` returns NXDOMAIN

**Solution**:
```bash
# Check Route53 hosted zone
aws route53 list-hosted-zones

# Check DNS records
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id>

# Verify external-dns is running
kubectl get deployment -n cluckin-bell external-dns
kubectl logs -n cluckin-bell deployment/external-dns

# Check ingress annotations
kubectl get ingress -n cluckin-bell -o yaml
# Should have: external-dns.alpha.kubernetes.io/hostname annotation
```

#### Issue: Pods Stuck in Pending

**Symptoms**:
- `kubectl get pods` shows pods in Pending state
- Error: "Insufficient cpu" or "Insufficient memory"

**Solution**:
```bash
# Check node capacity
kubectl describe nodes

# Check pending pods
kubectl describe pod <pod-name> -n cluckin-bell

# Scale up node group if needed
eksctl scale nodegroup \
  --cluster=cluckn-bell-nonprod \
  --name=dev \
  --nodes=<new-desired-count> \
  --region=us-east-1

# Or enable Cluster Autoscaler/Karpenter for automatic scaling
```

### Getting Help

If issues persist:

1. **Check CloudWatch Logs**:
   ```bash
   aws logs tail /aws/eks/cluckn-bell-nonprod/cluster --follow
   ```

2. **Check Kubernetes Events**:
   ```bash
   kubectl get events --all-namespaces --sort-by='.lastTimestamp'
   ```

3. **Review Terraform State**:
   ```bash
   cd envs/nonprod
   terraform show
   terraform state list
   ```

4. **Contact AWS Support** (if AWS service issue)

5. **Review Documentation**:
   - [docs/CLUSTERS_WITH_EKSCTL.md](CLUSTERS_WITH_EKSCTL.md) - eksctl usage
   - [docs/DEPLOYMENT.md](DEPLOYMENT.md) - Deployment procedures
   - [docs/ENVIRONMENTS.md](ENVIRONMENTS.md) - Environment details
   - [docs/github-actions-roles.md](github-actions-roles.md) - IAM OIDC setup

---

## Quick Reference

### Common Commands Cheat Sheet

```bash
# Authentication
make login-nonprod                              # Login to nonprod
make login-prod                                 # Login to prod

# Terraform
make tf-plan ENV=nonprod REGION=us-east-1       # Plan changes
make tf-apply ENV=nonprod REGION=us-east-1      # Apply changes
make tf-destroy ENV=nonprod REGION=us-east-1    # Destroy resources

# EKS Clusters
make eks-create-env ENV=nonprod REGION=us-east-1  # Create cluster
make eks-upgrade ENV=nonprod                      # Upgrade cluster
make eks-delete ENV=nonprod                       # Delete cluster

# IRSA Bootstrap
make irsa-nonprod                               # Bootstrap IRSA for nonprod
make irsa-prod                                  # Bootstrap IRSA for prod

# Outputs
make outputs ENV=nonprod                        # View all outputs

# Disaster Recovery
make dr-provision-prod REGION=us-west-2         # Provision DR in us-west-2

# Verification
make check-tools                                # Verify required tools
kubectl get nodes                               # Check cluster nodes
kubectl get pods -n cluckin-bell                # Check application pods
```

### Important File Locations

- **Makefile**: `/Makefile` - All operational commands
- **eksctl Configs**: `/eksctl/*.yaml` - Cluster configurations
- **Terraform Envs**: `/envs/nonprod/`, `/envs/prod/` - Environment-specific configs
- **GitHub Workflows**: `/.github/workflows/` - CI/CD workflows
- **Documentation**: `/docs/` - All operational docs

### Key Version Requirements

- Terraform: **1.13.1**
- Kubernetes: **1.33** (minimum 1.30)
- eksctl: **>= 1.34**
- AWS CLI: **>= 2.0**

### Support Contacts

- **Infrastructure Issues**: Check CloudWatch logs and Kubernetes events
- **AWS Issues**: Contact AWS Support
- **Application Issues**: Check application logs and ArgoCD sync status

---

## Appendix

### A. eksctl Cluster Configuration References

- **Nonprod**: `eksctl/devqa-cluster.yaml`
- **Prod**: `eksctl/prod-cluster.yaml`

Key configuration points:
- Kubernetes version: 1.33
- AMI Family: AmazonLinux2023
- OIDC: Enabled
- Add-ons: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, eks-pod-identity-agent
- CloudWatch logging: Enabled (7 days nonprod, 90 days prod)

### B. Related Documentation

- [CLUSTERS_WITH_EKSCTL.md](CLUSTERS_WITH_EKSCTL.md) - Complete eksctl guide
- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment procedures
- [ENVIRONMENTS.md](ENVIRONMENTS.md) - Environment details
- [github-actions-roles.md](github-actions-roles.md) - IAM OIDC setup
- [EKS_2025_BEST_PRACTICES.md](EKS_2025_BEST_PRACTICES.md) - EKS best practices
- [KARPENTER_MIGRATION.md](KARPENTER_MIGRATION.md) - Karpenter setup (optional)

### C. Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-12-17 | 1.0 | Initial runbook creation |

---

**End of Runbook**
