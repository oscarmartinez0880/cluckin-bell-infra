# Cluckin Bell Infrastructure Runbook

This runbook provides comprehensive operational guidance for managing the Cluckin Bell infrastructure, including day-to-day operations, disaster recovery procedures, and troubleshooting.

## Table of Contents

- [Environment Overview](#environment-overview)
- [Repository Variables and IAM OIDC Setup](#repository-variables-and-iam-oidc-setup)
- [Makefile Usage](#makefile-usage)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Disaster Recovery Playbook](#disaster-recovery-playbook)
- [Troubleshooting](#troubleshooting)

---

## Environment Overview

### Accounts and Clusters

The infrastructure is organized across two AWS accounts with a shared nonprod cluster and separate prod cluster:

| Environment | AWS Account ID | Account Name | Cluster Name | Kubernetes Version |
|-------------|---------------|--------------|--------------|-------------------|
| **Nonprod** (Dev+QA) | 264765154707 | cluckin-bell-qa | cluckn-bell-nonprod | 1.33+ |
| **Prod** | 346746763840 | cluckin-bell-prod | cluckn-bell-prod | 1.33+ |

### AWS SSO Portal

Access AWS accounts via SSO portal: **https://d-906622bbc4.awsapps.com/start/#/?tab=accounts**

### State Management

Terraform state is stored in S3 buckets:
- **Nonprod**: `cluckn-bell-tfstate-nonprod` (us-east-1)
- **Prod**: `cluckn-bell-tfstate-prod` (us-east-1)

### Technology Stack

- **Terraform Version**: 1.13.1
- **Kubernetes Version**: 1.33 (minimum 1.30)
- **EKS Management**: eksctl (clusters not managed by Terraform)
- **Container Registry**: Amazon ECR (per-account)
- **GitOps**: ArgoCD with AWS CodeCommit

### Architecture Principles

1. **Terraform** manages foundational AWS resources (VPC, IAM, Route53, ECR, WAF)
2. **eksctl** manages EKS cluster lifecycle (creation, upgrades, node groups, add-ons)
3. **Terraform post-cluster** bootstraps IRSA roles after cluster creation
4. **ArgoCD/Helm** manages all in-cluster Kubernetes resources

---

## Repository Variables and IAM OIDC Setup

### GitHub Repository Variables

The GitHub Actions workflows use repository variables to reference IAM role ARNs. These must be configured in your repository settings:

**Navigate to**: Repository → Settings → Secrets and variables → Actions → Variables

| Variable Name | Description | Example Value |
|--------------|-------------|---------------|
| `AWS_TERRAFORM_ROLE_ARN_NONPROD` | Terraform deployment role for nonprod | `arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa` |
| `AWS_TERRAFORM_ROLE_ARN_PROD` | Terraform deployment role for prod | `arn:aws:iam::346746763840:role/cb-terraform-deploy-prod` |
| `AWS_EKSCTL_ROLE_ARN_NONPROD` | eksctl management role for nonprod | `arn:aws:iam::264765154707:role/cb-eksctl-manage-devqa` |
| `AWS_EKSCTL_ROLE_ARN_PROD` | eksctl management role for prod | `arn:aws:iam::346746763840:role/cb-eksctl-manage-prod` |

### IAM OIDC Trust Setup

Each AWS account requires an OIDC provider for GitHub Actions authentication:

#### 1. Create OIDC Provider (One-time per account)

```bash
# In AWS Console or via CLI for each account:
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

#### 2. Create IAM Roles with Trust Policies

**Nonprod Terraform Role** (`cb-terraform-deploy-devqa`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::264765154707:oidc-provider/token.actions.githubusercontent.com"
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

Attach policies: `PowerUserAccess`, custom VPC/EKS/Route53 policies

**Prod Terraform Role** (`cb-terraform-deploy-prod`):
- Similar trust policy with account ID `346746763840`
- Same permission policies as nonprod

**eksctl Roles**:
- Similar structure with appropriate EKS management permissions
- Same trust policies scoped to your repository

#### 3. Verify OIDC Configuration

```bash
# List OIDC providers
aws iam list-open-id-connect-providers

# Verify role trust policy
aws iam get-role --role-name cb-terraform-deploy-devqa --query 'Role.AssumeRolePolicyDocument'
```

---

## Makefile Usage

The Makefile provides convenient commands for all infrastructure operations. All targets support environment and region overrides.

### Prerequisites Check

```bash
# Verify all required tools are installed
make check-tools
```

### Authentication

```bash
# Login to nonprod (DevQA) account
make login-nonprod

# Login to prod account
make login-prod
```

### Terraform Operations

All Terraform targets support `ENV` (nonprod|prod) and `REGION` (default: us-east-1) parameters.

#### Initialize

```bash
# Initialize Terraform for nonprod
make tf-init ENV=nonprod REGION=us-east-1

# Initialize Terraform for prod
make tf-init ENV=prod REGION=us-east-1
```

#### Plan

```bash
# Plan nonprod changes in us-east-1
make tf-plan ENV=nonprod REGION=us-east-1

# Plan prod changes in us-west-2 (DR region)
make tf-plan ENV=prod REGION=us-west-2
```

#### Apply

```bash
# Apply nonprod infrastructure
make tf-apply ENV=nonprod REGION=us-east-1

# Apply prod infrastructure
make tf-apply ENV=prod REGION=us-east-1
```

#### Destroy

```bash
# Destroy nonprod infrastructure (prompts for confirmation)
make tf-destroy ENV=nonprod REGION=us-east-1
```

### EKS Cluster Management

EKS clusters are managed via eksctl, separate from Terraform.

#### Create Cluster

```bash
# Create nonprod cluster (uses eksctl/devqa-cluster.yaml)
make eks-create-env ENV=nonprod REGION=us-east-1

# Create prod cluster (uses eksctl/prod-cluster.yaml)
make eks-create-env ENV=prod REGION=us-east-1
```

#### Upgrade Cluster

```bash
# Upgrade nonprod cluster to latest Kubernetes version
make eks-upgrade ENV=nonprod

# Upgrade prod cluster
make eks-upgrade ENV=prod
```

#### Delete Cluster

```bash
# Delete nonprod cluster (prompts for confirmation)
make eks-delete ENV=nonprod

# Delete prod cluster (prompts for confirmation)
make eks-delete ENV=prod
```

### View Infrastructure Outputs

```bash
# Print all Terraform outputs for nonprod
make outputs ENV=nonprod

# Print all Terraform outputs for prod
make outputs ENV=prod
```

**Useful outputs include**:
- VPC IDs and subnet IDs
- RDS endpoints
- ECR repository URLs
- IRSA role ARNs (cert-manager, external-dns, etc.)
- Load balancer URLs
- Karpenter IAM role ARNs

### Disaster Recovery

```bash
# One-command DR provisioning for prod in us-west-2
make dr-provision-prod REGION=us-west-2

# This interactive command will:
# 1. Prompt for confirmation
# 2. Login to prod account via SSO
# 3. Initialize Terraform
# 4. Show plan and prompt before apply
# 5. Apply Terraform infrastructure
# 6. Create EKS cluster via eksctl
# 7. Display next steps
```

### Complete Workflow Examples

#### Full Nonprod Deployment

```bash
# 1. Login to nonprod account
make login-nonprod

# 2. Initialize Terraform
make tf-init ENV=nonprod

# 3. Plan changes
make tf-plan ENV=nonprod

# 4. Apply infrastructure (VPC, IAM, Route53, etc.)
make tf-apply ENV=nonprod

# 5. Create EKS cluster
make eks-create-env ENV=nonprod

# 6. Bootstrap IRSA roles (post-cluster)
make irsa-nonprod

# 7. View outputs
make outputs ENV=nonprod
```

#### Full Prod Deployment

```bash
# 1. Login to prod account
make login-prod

# 2. Initialize and apply Terraform
make tf-init ENV=prod
make tf-plan ENV=prod
make tf-apply ENV=prod

# 3. Create EKS cluster
make eks-create-env ENV=prod

# 4. Bootstrap IRSA roles
make irsa-prod

# 5. Verify outputs
make outputs ENV=prod
```

---

## GitHub Actions Workflows

The repository provides three GitHub Actions workflows for infrastructure operations via the GitHub UI.

### 1. Infrastructure Terraform Workflow

**Workflow**: `.github/workflows/infra-terraform.yaml`

**Purpose**: Run Terraform operations (plan, apply, destroy) on infrastructure

**Usage**:
1. Navigate to **Actions** → **Infrastructure Terraform**
2. Click **Run workflow**
3. Select inputs:
   - **Environment**: `nonprod` or `prod`
   - **Action**: `plan`, `apply`, or `destroy`
   - **Region**: AWS region (default: `us-east-1`)

**Authentication**: Uses OIDC with role ARN from `vars.AWS_TERRAFORM_ROLE_ARN_*`

**Working Directory**: `envs/{environment}/`

**Example Use Cases**:
- Plan infrastructure changes before applying
- Apply approved Terraform changes
- Destroy test environments

### 2. EKS Cluster Management Workflow

**Workflow**: `.github/workflows/eksctl-cluster.yaml`

**Purpose**: Manage EKS cluster lifecycle (create, upgrade, delete)

**Usage**:
1. Navigate to **Actions** → **EKS Cluster Management**
2. Click **Run workflow**
3. Select inputs:
   - **Environment**: `nonprod` or `prod`
   - **Operation**: `create`, `upgrade`, or `delete`
   - **Region**: AWS region (default: `us-east-1`)

**Authentication**: Uses OIDC with role ARN from `vars.AWS_EKSCTL_ROLE_ARN_*`

**Cluster Configs**:
- Nonprod: `eksctl/devqa-cluster.yaml`
- Prod: `eksctl/prod-cluster.yaml`

**Example Use Cases**:
- Create new EKS clusters
- Upgrade Kubernetes version across clusters
- Decommission old clusters

### 3. Disaster Recovery Launch Workflow

**Workflow**: `.github/workflows/dr-launch-prod.yaml`

**Purpose**: Rapidly provision production infrastructure in alternate region

**Usage**:
1. Navigate to **Actions** → **Disaster Recovery - Launch Prod**
2. Click **Run workflow**
3. Select inputs:
   - **Region**: DR region (e.g., `us-west-2`, `eu-west-1`)

**Authentication**: Uses OIDC with role ARN from `vars.AWS_TERRAFORM_ROLE_ARN_PROD`

**Steps Performed**:
1. Provision VPC, RDS, ECR, and other infrastructure via Terraform
2. Create EKS cluster using eksctl
3. Display infrastructure outputs
4. Show next steps for completing DR setup

**Post-Workflow Actions**:
- Bootstrap IRSA roles: `make irsa-prod REGION={region}`
- Deploy applications via ArgoCD
- Update DNS records
- Verify service health

**Estimated Time**: 30-45 minutes

---

## Disaster Recovery Playbook

This section provides comprehensive guidance for disaster recovery scenarios.

### DR Architecture

- **Primary Region**: `us-east-1` (default production)
- **DR Regions**: Any supported AWS region (e.g., `us-west-2`, `eu-west-1`, `ap-southeast-1`)
- **RTO Target**: < 4 hours for full environment
- **RPO Target**: Based on RDS backup schedule and Multi-AZ configuration

### Optional DR Features (Terraform)

The infrastructure includes optional DR toggles that can be enabled in Terraform. All features are **disabled by default** to avoid costs.

#### 1. ECR Cross-Region Replication

Automatically replicates container images to DR regions.

**Enable in `envs/prod/prod.auto.tfvars`**:
```hcl
enable_ecr_replication  = true
ecr_replication_regions = ["us-west-2", "eu-west-1"]
```

**Cost**: Storage costs in target regions + data transfer

**Validation**:
```bash
# Verify replication rule exists
aws ecr describe-registry --region us-east-1 | jq '.replicationConfiguration'

# Check replicated images in DR region
aws ecr describe-repositories --region us-west-2
```

#### 2. Secrets Manager Replication

Replicates application secrets to DR regions.

**Enable in `envs/prod/prod.auto.tfvars`**:
```hcl
enable_secrets_replication  = true
secrets_replication_regions = ["us-west-2"]
```

**Note**: Add secret IDs to replicate in `envs/prod/main.tf` DR module block:
```hcl
module "dr" {
  # ...
  secret_ids = [
    "arn:aws:secretsmanager:us-east-1:346746763840:secret:/cluckn-bell/db-password-abc123",
    "/cluckn-bell/app/api-key"
  ]
}
```

**Cost**: ~$0.40/month per secret replica

**Validation**:
```bash
# List secrets in DR region
aws secretsmanager list-secrets --region us-west-2

# Verify secret replication status
aws secretsmanager describe-secret \
  --secret-id /cluckn-bell/db-password \
  --region us-west-2
```

#### 3. Route53 DNS Failover

Configures health checks and failover DNS records for automatic failover.

**Enable in `envs/prod/prod.auto.tfvars`**:
```hcl
enable_dns_failover = true

failover_records = {
  "api" = {
    name               = "api.cluckn-bell.com"
    type               = "CNAME"
    primary_endpoint   = "api-primary-lb.us-east-1.elb.amazonaws.com"
    secondary_endpoint = "api-secondary-lb.us-west-2.elb.amazonaws.com"
    health_check_path  = "/health"
  }
  "web" = {
    name               = "www.cluckn-bell.com"
    type               = "CNAME"
    primary_endpoint   = "web-primary-lb.us-east-1.elb.amazonaws.com"
    secondary_endpoint = "web-secondary-lb.us-west-2.elb.amazonaws.com"
    health_check_path  = "/health"
  }
}
```

**Cost**: ~$0.50/month per health check

**Validation**:
```bash
# Check health check status
aws route53 list-health-checks

# View health check status
aws route53 get-health-check-status --health-check-id HEALTH_CHECK_ID

# Test failover DNS resolution
dig api.cluckn-bell.com
```

### DR Provisioning Methods

#### Method 1: GitHub Actions (Recommended)

**Advantages**: Automated, audited, no local dependencies

1. Navigate to **Actions** → **Disaster Recovery - Launch Prod**
2. Click **Run workflow**
3. Select DR region (e.g., `us-west-2`)
4. Monitor workflow progress
5. Follow post-workflow steps displayed in summary

**Estimated Time**: 30-45 minutes

#### Method 2: Makefile

**Advantages**: More control, can be run locally

```bash
# Interactive DR provisioning with prompts
make dr-provision-prod REGION=us-west-2
```

**Estimated Time**: 30-45 minutes

#### Method 3: Manual Steps

**Advantages**: Complete control, useful for troubleshooting

```bash
# 1. Login to prod account
make login-prod

# 2. Initialize Terraform
cd envs/prod
terraform init -backend-config=backend.hcl

# 3. Plan infrastructure
terraform plan -var="aws_region=us-west-2"

# 4. Apply infrastructure
terraform apply -var="aws_region=us-west-2"

# 5. Create EKS cluster
cd ../..
AWS_PROFILE=cluckin-bell-prod eksctl create cluster \
  -f eksctl/prod-cluster.yaml \
  --region us-west-2

# 6. Bootstrap IRSA roles
make irsa-prod REGION=us-west-2

# 7. Verify outputs
make outputs ENV=prod
```

**Estimated Time**: 45-60 minutes

### Post-Provisioning Steps

#### 1. Verify Infrastructure

```bash
# Check EKS cluster status
aws eks describe-cluster --name cluckn-bell-prod --region us-west-2

# Check RDS instance
aws rds describe-db-instances --region us-west-2 | jq '.DBInstances[].Endpoint'

# Check VPC and subnets
aws ec2 describe-vpcs --region us-west-2 --filters "Name=tag:Project,Values=cluckin-bell"
```

#### 2. Configure kubectl

```bash
# Update kubeconfig for DR cluster
aws eks update-kubeconfig --name cluckn-bell-prod --region us-west-2

# Verify nodes are ready
kubectl get nodes

# Check system pods
kubectl get pods -A
```

#### 3. Deploy Platform Components

```bash
# Bootstrap IRSA roles (if not done via Makefile)
cd stacks/irsa-bootstrap
terraform init
terraform apply \
  -var "cluster_name=cluckn-bell-prod" \
  -var "region=us-west-2" \
  -var "environment=prod"

# Verify IRSA role outputs
terraform output
```

#### 4. Restore Database (if needed)

```bash
# Option A: Restore from automated backup
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier prod-db-dr \
  --db-snapshot-identifier prod-db-snapshot-2024-01-15 \
  --region us-west-2

# Option B: Restore from point-in-time (if enabled)
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier prod-db-primary \
  --target-db-instance-identifier prod-db-dr \
  --restore-time 2024-01-15T12:00:00Z \
  --region us-west-2

# Wait for database to be available
aws rds wait db-instance-available \
  --db-instance-identifier prod-db-dr \
  --region us-west-2
```

#### 5. Deploy Applications

```bash
# Deploy ArgoCD
kubectl create namespace cluckin-bell
kubectl apply -n cluckin-bell -f charts/argocd/

# Get ArgoCD admin password
kubectl -n cluckin-bell get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Configure ArgoCD applications
# Deploy via ArgoCD UI or kubectl apply -f apps/
```

#### 6. Update DNS Records

**Manual DNS Update**:
```bash
# Update Route53 records to point to DR region
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://dns-change.json
```

**Using DNS Failover** (if enabled):
- Health checks automatically detect primary region failure
- Traffic automatically fails over to secondary (DR) region
- No manual DNS changes needed

**Gradual Cutover** (recommended):
```bash
# Use weighted routing for gradual traffic shift
# 10% traffic to DR region initially
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.cluckn-bell.com",
        "Type": "CNAME",
        "SetIdentifier": "dr-region",
        "Weight": 10,
        "TTL": 60,
        "ResourceRecords": [{"Value": "api-dr-lb.us-west-2.elb.amazonaws.com"}]
      }
    }]
  }'

# Monitor and gradually increase weight to 100%
```

#### 7. Verification and Testing

```bash
# Test application endpoints
curl -v https://api.cluckn-bell.com/health
curl -v https://www.cluckn-bell.com/

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EKS \
  --metric-name cluster_failed_node_count \
  --dimensions Name=ClusterName,Value=cluckn-bell-prod \
  --start-time 2024-01-15T00:00:00Z \
  --end-time 2024-01-15T23:59:59Z \
  --period 300 \
  --statistics Average \
  --region us-west-2

# Verify certificate renewal
kubectl get certificate -A
kubectl describe certificate -n cluckin-bell

# Run smoke tests
# (Run your application-specific test suite)
```

### Rollback Procedure

If DR activation needs to be reversed:

```bash
# 1. DO NOT destroy DR infrastructure (keep for future use)

# 2. Update DNS to point back to primary region
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.cluckn-bell.com",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [{"Value": "api-primary-lb.us-east-1.elb.amazonaws.com"}]
      }
    }]
  }'

# 3. Verify primary region health
aws eks describe-cluster --name cluckn-bell-prod --region us-east-1
kubectl get nodes --context primary-cluster

# 4. Monitor traffic shift back to primary
# Watch CloudWatch metrics and application logs

# 5. Keep DR environment running for future testing
# Scale down node groups if desired to reduce costs
kubectl scale deployment --all --replicas=0 -n cluckin-bell
```

### DR Testing Schedule

Regular DR testing is essential:

- **Quarterly**: Test DR provisioning workflow end-to-end
- **Semi-Annually**: Full DR failover test with application traffic
- **Annually**: Complete DR drill including database restore and cutover
- **After Changes**: Test DR provisioning after significant infrastructure changes

### DR Testing Checklist

- [ ] Verify DR region infrastructure can be provisioned within RTO
- [ ] Test database restore from backup/snapshot
- [ ] Validate application deployment in DR region
- [ ] Test DNS failover (manual or automatic)
- [ ] Verify monitoring and alerting in DR region
- [ ] Confirm certificate issuance/renewal works
- [ ] Test application functionality end-to-end
- [ ] Validate rollback procedure
- [ ] Document lessons learned and update runbook

---

## Troubleshooting

### Common Issues

#### 1. AWS SSO Login Failures

**Symptom**: `make login-nonprod` fails with "Session token expired"

**Solution**:
```bash
# Clear SSO cache
rm -rf ~/.aws/sso/cache/

# Re-login
aws sso login --profile cluckin-bell-qa
```

#### 2. Terraform State Lock

**Symptom**: Terraform operations fail with "Error acquiring state lock"

**Solution**:
```bash
# View current lock
aws dynamodb get-item \
  --table-name terraform-state-lock \
  --key '{"LockID":{"S":"cluckn-bell-tfstate-nonprod/nonprod/terraform.tfstate-md5"}}'

# Force unlock (use with caution)
cd envs/nonprod
terraform force-unlock LOCK_ID
```

#### 3. eksctl Cluster Creation Timeout

**Symptom**: `make eks-create-env` times out or fails

**Solution**:
```bash
# Check CloudFormation stacks
aws cloudformation describe-stacks --region us-east-1 | grep eksctl-cluckn-bell

# View stack events for errors
aws cloudformation describe-stack-events \
  --stack-name eksctl-cluckn-bell-nonprod-cluster \
  --region us-east-1

# Delete failed stack and retry
eksctl delete cluster --name cluckn-bell-nonprod --region us-east-1
```

#### 4. GitHub Actions OIDC Authentication Failures

**Symptom**: Workflow fails with "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Solution**:
```bash
# 1. Verify OIDC provider exists
aws iam list-open-id-connect-providers

# 2. Check role trust policy
aws iam get-role --role-name cb-terraform-deploy-devqa \
  --query 'Role.AssumeRolePolicyDocument'

# 3. Verify repository variables are set correctly
# Navigate to: GitHub Repo → Settings → Secrets and variables → Actions → Variables

# 4. Ensure trust policy includes correct repository
# Trust policy should have: "repo:oscarmartinez0880/cluckin-bell-infra:*"
```

#### 5. EKS Cluster Not Accessible

**Symptom**: `kubectl` commands fail with "Unable to connect to the server"

**Solution**:
```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name cluckn-bell-nonprod \
  --region us-east-1 \
  --profile cluckin-bell-qa

# Verify cluster is running
aws eks describe-cluster \
  --name cluckn-bell-nonprod \
  --region us-east-1

# Check node status
kubectl get nodes

# View node issues
kubectl describe nodes
```

#### 6. IRSA Role Creation Fails

**Symptom**: `make irsa-nonprod` fails with "OIDC provider not found"

**Solution**:
```bash
# Ensure cluster exists and OIDC is enabled
aws eks describe-cluster \
  --name cluckn-bell-nonprod \
  --region us-east-1 \
  --query 'cluster.identity.oidc.issuer'

# Associate OIDC provider if missing
eksctl utils associate-iam-oidc-provider \
  --cluster cluckn-bell-nonprod \
  --region us-east-1 \
  --approve
```

#### 7. DR Provisioning Fails in Target Region

**Symptom**: `make dr-provision-prod REGION=us-west-2` fails with "Service not available in region"

**Solution**:
```bash
# Verify all required services are available in target region
aws ec2 describe-regions --region-names us-west-2

# Check EKS availability
aws eks list-clusters --region us-west-2

# Some regions may not support all instance types
# Update eksctl config if needed with region-appropriate instance types
```

### Support and Escalation

For additional support:

1. **Check existing documentation**: Review README.md and other docs/ files
2. **Review CloudWatch Logs**: Check application and infrastructure logs
3. **Terraform State**: Inspect state for resource details
4. **AWS Support**: Open support case for AWS-specific issues
5. **Team Escalation**: Contact infrastructure team lead

### Useful Commands Reference

```bash
# Check AWS credentials
aws sts get-caller-identity

# List EKS clusters
aws eks list-clusters --region us-east-1

# View Terraform state
terraform state list
terraform state show <resource>

# View kubectl context
kubectl config current-context
kubectl config get-contexts

# Check pod logs
kubectl logs -f <pod-name> -n cluckin-bell

# Port-forward to service
kubectl port-forward svc/argocd-server -n cluckin-bell 8080:80

# Execute commands in pod
kubectl exec -it <pod-name> -n cluckin-bell -- /bin/bash
```

---

## Appendix

### Repository Structure Quick Reference

```
cluckin-bell-infra/
├── .github/workflows/       # GitHub Actions workflows
│   ├── infra-terraform.yaml
│   ├── eksctl-cluster.yaml
│   └── dr-launch-prod.yaml
├── envs/                    # Environment-specific configs
│   ├── nonprod/
│   └── prod/
├── eksctl/                  # eksctl cluster configs
│   ├── devqa-cluster.yaml
│   └── prod-cluster.yaml
├── modules/                 # Terraform modules
│   ├── vpc/
│   ├── dns-certs/
│   ├── irsa/
│   ├── dr/                  # DR module (new)
│   └── ...
├── docs/                    # Documentation
│   └── Runbook.md          # This file
└── Makefile                # Automation commands
```

### Key Configuration Files

- `envs/nonprod/nonprod.auto.tfvars`: Nonprod environment variables
- `envs/prod/prod.auto.tfvars`: Prod environment variables
- `eksctl/devqa-cluster.yaml`: Nonprod EKS cluster configuration
- `eksctl/prod-cluster.yaml`: Prod EKS cluster configuration
- `Makefile`: Automation targets and commands

### Additional Documentation

- [README.md](../README.md): Main repository overview
- [ENVIRONMENTS.md](ENVIRONMENTS.md): Detailed environment information
- [DEPLOYMENT.md](DEPLOYMENT.md): Deployment procedures
- [CLUSTERS_WITH_EKSCTL.md](CLUSTERS_WITH_EKSCTL.md): eksctl cluster management guide
- [modules/dr/README.md](../modules/dr/README.md): DR module documentation

---

**Last Updated**: 2024-01-15  
**Maintainer**: Infrastructure Team  
**Review Schedule**: Quarterly
