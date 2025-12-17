# Cluckin Bell Infrastructure Runbook

This runbook provides comprehensive guidance for managing the Cluckin Bell infrastructure, including day-to-day operations, disaster recovery procedures, and troubleshooting.

## Table of Contents

1. [Environment Overview](#environment-overview)
2. [Repository Variables and IAM OIDC Setup](#repository-variables-and-iam-oidc-setup)
3. [Makefile Usage](#makefile-usage)
4. [GitHub Actions Workflows](#github-actions-workflows)
5. [Disaster Recovery Playbook](#disaster-recovery-playbook)
6. [Troubleshooting](#troubleshooting)

---

## Environment Overview

### Accounts and Clusters

Cluckin Bell infrastructure is organized into two AWS accounts with separate EKS clusters:

| Environment | Account ID | Account Name | Cluster Name | Kubernetes Version | Namespaces | Domain |
|-------------|------------|--------------|--------------|-------------------|------------|--------|
| **Nonprod** | 264765154707 | cluckin-bell-qa | cluckn-bell-nonprod | 1.33 | dev, qa | dev.cluckn-bell.com, qa.cluckn-bell.com |
| **Prod** | 346746763840 | cluckin-bell-prod | cluckn-bell-prod | 1.33 | prod | cluckn-bell.com |

### AWS SSO Portal

Access both accounts via AWS SSO:
- **Portal URL**: https://d-906622bbc4.awsapps.com/start/#/?tab=accounts
- **Nonprod Profile**: `cluckin-bell-qa`
- **Prod Profile**: `cluckin-bell-prod`

### State Management

Terraform state is stored in dedicated S3 buckets:
- **Nonprod**: `cluckn-bell-tfstate-nonprod` (region: us-east-1)
- **Prod**: `cluckn-bell-tfstate-prod` (region: us-east-1)

### Tool Versions

- **Terraform**: 1.13.1
- **Kubernetes**: 1.33 (minimum 1.30 supported)
- **eksctl**: Latest (manages cluster lifecycle)

### Architecture Principles

- **Terraform** manages foundational AWS resources (VPCs, IAM, Route53, ECR, WAF)
- **eksctl** manages EKS cluster lifecycle (creation, upgrades, node groups)
- **ArgoCD/Helm** manages in-cluster resources (controllers, applications)
- **No Kubernetes resources in Terraform** - clusters are created and managed via eksctl

---

## Repository Variables and IAM OIDC Setup

### Required Repository Variables

GitHub Actions workflows use repository variables to reference IAM role ARNs for OIDC authentication. Configure the following variables in your GitHub repository settings (Settings → Secrets and variables → Actions → Variables):

| Variable Name | Description | Example Value |
|---------------|-------------|---------------|
| `AWS_TERRAFORM_ROLE_ARN_NONPROD` | IAM role for Terraform operations in nonprod | `arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa` |
| `AWS_TERRAFORM_ROLE_ARN_PROD` | IAM role for Terraform operations in prod | `arn:aws:iam::346746763840:role/cb-terraform-deploy-prod` |
| `AWS_EKSCTL_ROLE_ARN_NONPROD` | IAM role for eksctl operations in nonprod | `arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa` |
| `AWS_EKSCTL_ROLE_ARN_PROD` | IAM role for eksctl operations in prod | `arn:aws:iam::346746763840:role/cb-terraform-deploy-prod` |

### IAM OIDC Trust Setup

Each IAM role must have a trust policy that allows GitHub Actions to assume the role via OIDC. Example trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
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

### Required IAM Permissions

The IAM roles must have permissions for:
- **Terraform role**: VPC, IAM, Route53, ECR, Secrets Manager, CloudWatch, S3 (state bucket)
- **eksctl role**: EKS, EC2, IAM (for node roles), CloudFormation, VPC (read)

---

## Makefile Usage

The top-level Makefile provides convenient targets for common operations.

### Prerequisites

Ensure required tools are installed:
```bash
make check-tools
```

### AWS SSO Login

Always login before running infrastructure commands:

```bash
# Login to nonprod account
make login-nonprod

# Login to prod account
make login-prod
```

### Terraform Operations

All Terraform operations require `ENV` (nonprod|prod) and optionally `REGION` (default: us-east-1):

```bash
# Initialize Terraform for nonprod
make tf-init ENV=nonprod

# Plan changes for prod in us-west-2
make tf-plan ENV=prod REGION=us-west-2

# Apply changes for nonprod
make tf-apply ENV=nonprod

# Destroy resources (with confirmation prompt)
make tf-destroy ENV=prod REGION=us-east-1
```

### EKS Cluster Management

Cluster operations also require `ENV` and optionally `REGION`:

```bash
# Create nonprod cluster
make eks-create ENV=nonprod REGION=us-east-1

# Upgrade prod cluster to latest Kubernetes version
make eks-upgrade ENV=prod

# Delete nonprod cluster (with confirmation prompt)
make eks-delete ENV=nonprod
```

### View Outputs

Display Terraform outputs for an environment:

```bash
# View nonprod outputs
make outputs ENV=nonprod

# View prod outputs
make outputs ENV=prod
```

### Disaster Recovery Provisioning

Provision production infrastructure in an alternate region (includes Terraform and EKS cluster):

```bash
# Provision prod in us-west-2 for DR
make dr-provision-prod REGION=us-west-2
```

This target will:
1. Login to prod account via SSO
2. Initialize Terraform in `envs/prod`
3. Run `terraform plan` and prompt for approval
4. Run `terraform apply` to provision infrastructure
5. Create EKS cluster using eksctl with prod configuration
6. Display next steps for IRSA and application deployment

---

## GitHub Actions Workflows

All workflows are manually triggered via workflow_dispatch. Access them from the GitHub UI under Actions tab.

### Infrastructure Terraform Workflow

**File**: `.github/workflows/infra-terraform.yaml`

**Purpose**: Manage Terraform infrastructure (VPC, IAM, Route53, ECR, etc.)

**Inputs**:
- `environment`: nonprod or prod
- `action`: plan, apply, or destroy
- `region`: AWS region (default: us-east-1)

**Usage**:
1. Navigate to Actions → Infrastructure Terraform
2. Click "Run workflow"
3. Select environment, action, and region
4. Click "Run workflow"

**IAM Role**: Uses `vars.AWS_TERRAFORM_ROLE_ARN_NONPROD` or `vars.AWS_TERRAFORM_ROLE_ARN_PROD`

**Example Scenarios**:
- Plan nonprod changes: `environment=nonprod, action=plan, region=us-east-1`
- Apply prod infrastructure: `environment=prod, action=apply, region=us-east-1`
- Destroy nonprod resources: `environment=nonprod, action=destroy, region=us-east-1`

### EKS Cluster Management Workflow

**File**: `.github/workflows/eksctl-cluster.yaml`

**Purpose**: Manage EKS cluster lifecycle using eksctl

**Inputs**:
- `environment`: nonprod or prod
- `operation`: create, upgrade, or delete
- `region`: AWS region (default: us-east-1)

**Usage**:
1. Navigate to Actions → EKS Cluster Management
2. Click "Run workflow"
3. Select environment, operation, and region
4. Click "Run workflow"

**IAM Role**: Uses `vars.AWS_EKSCTL_ROLE_ARN_NONPROD` or `vars.AWS_EKSCTL_ROLE_ARN_PROD`

**Example Scenarios**:
- Create nonprod cluster: `environment=nonprod, operation=create, region=us-east-1`
- Upgrade prod cluster: `environment=prod, operation=upgrade, region=us-east-1`
- Delete nonprod cluster: `environment=nonprod, operation=delete, region=us-east-1`

### Disaster Recovery Launch Workflow

**File**: `.github/workflows/dr-launch-prod.yaml`

**Purpose**: Provision prod infrastructure and EKS cluster in an alternate region for disaster recovery

**Inputs**:
- `region`: Target AWS region (us-west-2, us-west-1, eu-west-1, eu-central-1, ap-southeast-1, ap-northeast-1)

**Usage**:
1. Navigate to Actions → Disaster Recovery - Launch Prod
2. Click "Run workflow"
3. Select target region
4. Click "Run workflow"

**IAM Role**: Uses `vars.AWS_TERRAFORM_ROLE_ARN_PROD`

**What it does**:
1. Provisions Terraform infrastructure in target region
2. Creates EKS cluster using eksctl
3. Displays outputs and next steps

**Example Scenario**:
- Launch DR in us-west-2: `region=us-west-2`

---

## Disaster Recovery Playbook

This section provides step-by-step procedures for disaster recovery scenarios.

### DR Architecture Overview

Cluckin Bell DR strategy includes optional toggles for:
- **ECR Cross-Region Replication**: Automatically replicate container images to DR region
- **Secrets Manager Replication**: Replicate application secrets to DR region
- **Route53 DNS Failover**: Health check-based failover between primary and secondary regions

All DR features are **disabled by default** and can be enabled via Terraform variables.

### DR Configuration Variables

Enable DR features by setting these variables in `envs/{environment}/{environment}.auto.tfvars`:

```hcl
# ECR Replication
enable_ecr_replication    = true
ecr_replication_regions   = ["us-west-2"]

# Secrets Manager Replication
enable_secrets_replication  = true
secrets_replication_regions = ["us-west-2"]

# Route53 DNS Failover
enable_dns_failover = true
failover_records = {
  "api" = {
    name                  = "api.cluckn-bell.com"
    type                  = "A"
    ttl                   = 60
    primary_value         = "3.230.45.67"      # Primary region ELB IP
    secondary_value       = "54.186.123.45"    # Secondary region ELB IP
    health_check_interval = 30
    health_check_path     = "/health"
  }
  "app" = {
    name                  = "app.cluckn-bell.com"
    type                  = "A"
    ttl                   = 60
    primary_value         = "3.230.45.68"
    secondary_value       = "54.186.123.46"
    health_check_interval = 30
    health_check_path     = "/"
  }
}
```

### Pre-Disaster Preparation

#### 1. Enable ECR Replication (Optional)

**Purpose**: Automatically replicate container images to DR region

**Steps**:
1. Edit `envs/prod/prod.auto.tfvars`:
   ```hcl
   enable_ecr                = true
   enable_ecr_replication    = true
   ecr_replication_regions   = ["us-west-2"]
   ```

2. Apply changes:
   ```bash
   make login-prod
   make tf-apply ENV=prod REGION=us-east-1
   ```

3. Verify replication:
   ```bash
   aws ecr describe-registry --region us-west-2 --profile cluckin-bell-prod
   ```

**Validation**:
- Push a test image to primary region
- Verify image appears in us-west-2 repository within 5-10 minutes

#### 2. Enable Secrets Manager Replication (Optional)

**Purpose**: Replicate application secrets to DR region

**Steps**:
1. Edit `envs/prod/prod.auto.tfvars`:
   ```hcl
   enable_secrets              = true
   enable_secrets_replication  = true
   secrets_replication_regions = ["us-west-2"]
   ```

2. Apply changes:
   ```bash
   make login-prod
   make tf-apply ENV=prod REGION=us-east-1
   ```

3. Verify replication:
   ```bash
   aws secretsmanager list-secrets --region us-west-2 --profile cluckin-bell-prod
   ```

**Validation**:
- Secrets should appear in us-west-2 within 1-2 minutes
- Test secret retrieval: `aws secretsmanager get-secret-value --secret-id <arn> --region us-west-2`

#### 3. Configure DNS Failover (Optional)

**Purpose**: Automatic failover to DR region on primary region failure

**Prerequisites**:
- DR infrastructure must be provisioned and healthy
- Application endpoints must be deployed in both regions

**Steps**:
1. Determine primary and secondary endpoint IPs/hostnames
2. Edit `envs/prod/prod.auto.tfvars`:
   ```hcl
   enable_dns_failover = true
   failover_records = {
     # Configure failover records per above example
   }
   ```

3. Apply changes:
   ```bash
   make login-prod
   make tf-apply ENV=prod REGION=us-east-1
   ```

4. Verify health checks:
   ```bash
   aws route53 list-health-checks --profile cluckin-bell-prod
   ```

**Validation**:
- Health checks should show "Healthy" status
- Test DNS resolution: `dig api.cluckn-bell.com`
- Simulate primary failure by stopping primary endpoint, verify DNS fails over

### Disaster Scenarios

#### Scenario 1: Complete Region Failure (Primary us-east-1)

**Detection**:
- AWS Health Dashboard shows region issues
- Monitoring alerts for service degradation
- Route53 health checks failing (if DNS failover enabled)

**Response Steps**:

1. **Assess Impact**
   ```bash
   # Check AWS Service Health
   # Visit: https://status.aws.amazon.com/
   
   # Check Route53 health checks
   make login-prod
   aws route53 get-health-check-status --health-check-id <id>
   ```

2. **Provision DR Infrastructure** (if not pre-provisioned)
   ```bash
   # Via Makefile
   make dr-provision-prod REGION=us-west-2
   
   # OR via GitHub Actions
   # Navigate to Actions → Disaster Recovery - Launch Prod
   # Select region: us-west-2
   ```

3. **Bootstrap IRSA Roles**
   ```bash
   make login-prod
   cd stacks/irsa-bootstrap
   terraform init
   terraform apply \
     -var "cluster_name=cluckn-bell-prod" \
     -var "region=us-west-2" \
     -var "environment=prod"
   ```

4. **Deploy Applications**
   ```bash
   # Update ArgoCD to point to DR cluster
   # Deploy via existing CI/CD pipelines
   # Or manually deploy critical services
   ```

5. **Verify Services**
   ```bash
   # Update kubeconfig
   aws eks update-kubeconfig \
     --name cluckn-bell-prod \
     --region us-west-2 \
     --profile cluckin-bell-prod
   
   # Check pod status
   kubectl get pods -A
   
   # Verify service endpoints
   kubectl get svc -A
   ```

6. **Update DNS** (if DNS failover not enabled)
   ```bash
   # Manual DNS update via Route53 console or CLI
   aws route53 change-resource-record-sets \
     --hosted-zone-id <zone-id> \
     --change-batch file://dns-cutover.json
   ```

**Validation**:
- All critical services running in DR region
- DNS resolves to DR region endpoints
- Application functionality verified
- Monitoring dashboards showing healthy metrics

#### Scenario 2: EKS Cluster Failure (Cluster-Level Issue)

**Detection**:
- Cluster API server unreachable
- Node groups unhealthy
- CloudWatch logs showing errors

**Response Steps**:

1. **Attempt Cluster Recovery**
   ```bash
   # Check cluster status
   make login-prod
   aws eks describe-cluster --name cluckn-bell-prod --region us-east-1
   
   # Check node groups
   aws eks list-nodegroups --cluster-name cluckn-bell-prod --region us-east-1
   ```

2. **If Recovery Fails, Recreate Cluster**
   ```bash
   # Backup critical data and configs
   # Delete failed cluster
   make eks-delete ENV=prod REGION=us-east-1
   
   # Recreate cluster
   make eks-create ENV=prod REGION=us-east-1
   
   # Bootstrap IRSA
   # Redeploy applications
   ```

3. **Verify Recovery**
   ```bash
   kubectl get nodes
   kubectl get pods -A
   ```

#### Scenario 3: Data Loss in Primary Region

**Detection**:
- Database corruption alerts
- Missing persistent volume data
- Application errors related to data

**Response Steps**:

1. **Assess Data Loss**
   - Identify affected databases/volumes
   - Determine last known good backup

2. **Restore from Backups**
   ```bash
   # RDS restore (if applicable)
   aws rds restore-db-instance-from-db-snapshot \
     --db-instance-identifier prod-restored \
     --db-snapshot-identifier <snapshot-id>
   
   # EBS snapshot restore (if applicable)
   aws ec2 create-volume \
     --snapshot-id <snapshot-id> \
     --availability-zone us-east-1a
   ```

3. **Verify Data Integrity**
   - Connect to restored database
   - Run integrity checks
   - Verify application can read data

### DR Testing and Validation

#### Quarterly DR Test Checklist

- [ ] Provision DR infrastructure in us-west-2
- [ ] Verify ECR replication (if enabled)
- [ ] Verify Secrets Manager replication (if enabled)
- [ ] Deploy applications to DR cluster
- [ ] Test application functionality end-to-end
- [ ] Verify monitoring and alerting
- [ ] Test DNS failover (if enabled)
- [ ] Document issues and gaps
- [ ] Clean up DR resources (or leave for next test)
- [ ] Update runbook with lessons learned

#### DR Test Commands

```bash
# 1. Provision DR
make dr-provision-prod REGION=us-west-2

# 2. Bootstrap IRSA
cd stacks/irsa-bootstrap
terraform init
terraform apply -var="cluster_name=cluckn-bell-prod" -var="region=us-west-2" -var="environment=prod"

# 3. Deploy test application
kubectl apply -f test-app.yaml

# 4. Verify endpoints
kubectl get svc -n cluckin-bell

# 5. Test DNS failover (if enabled)
# Stop primary endpoint, verify DNS switches to secondary

# 6. Clean up
make tf-destroy ENV=prod REGION=us-west-2
make eks-delete ENV=prod REGION=us-west-2
```

### Rollback Procedures

#### Rolling Back Infrastructure Changes

```bash
# 1. Identify issue
make outputs ENV=prod

# 2. Revert Terraform changes
cd envs/prod
git revert <commit-hash>

# 3. Apply reverted state
make tf-apply ENV=prod

# 4. Verify
make outputs ENV=prod
```

#### Rolling Back to Primary Region

After DR event is resolved and primary region is restored:

1. **Verify Primary Region Health**
   ```bash
   aws health describe-events --region us-east-1
   ```

2. **Sync Latest Data to Primary** (if applicable)
   - Database replication
   - Storage sync
   - Configuration updates

3. **Deploy Applications to Primary**
   ```bash
   # Update kubeconfig to primary cluster
   aws eks update-kubeconfig \
     --name cluckn-bell-prod \
     --region us-east-1 \
     --profile cluckin-bell-prod
   
   # Deploy applications
   kubectl apply -f applications/
   ```

4. **Verify Primary Services**
   ```bash
   kubectl get pods -A
   kubectl get svc -A
   # Test application endpoints
   ```

5. **Update DNS Back to Primary** (if manual DNS)
   ```bash
   aws route53 change-resource-record-sets \
     --hosted-zone-id <zone-id> \
     --change-batch file://dns-rollback.json
   ```

6. **Monitor for Issues**
   - Watch CloudWatch logs
   - Check application metrics
   - Verify user traffic

7. **Decommission DR Resources** (optional)
   ```bash
   make tf-destroy ENV=prod REGION=us-west-2
   make eks-delete ENV=prod REGION=us-west-2
   ```

---

## Troubleshooting

### Common Issues

#### Issue: `make login-nonprod` fails with SSO error

**Symptoms**: 
```
Error loading SSO Token: Token for cluckin-bell-qa does not exist
```

**Solution**:
```bash
# Clear SSO cache
rm -rf ~/.aws/sso/cache/

# Login again
make login-nonprod
```

#### Issue: Terraform state locked

**Symptoms**:
```
Error: Error acquiring the state lock
Lock Info:
  ID:        <lock-id>
```

**Solution**:
```bash
# Verify no other operations are running
# Force unlock (use with caution)
cd envs/nonprod  # or envs/prod
terraform force-unlock <lock-id>
```

#### Issue: eksctl cluster creation fails

**Symptoms**:
```
Error: CloudFormation stack creation failed
```

**Solution**:
```bash
# Check CloudFormation stacks
aws cloudformation describe-stacks --region us-east-1 --profile cluckin-bell-qa

# View stack events for errors
aws cloudformation describe-stack-events \
  --stack-name eksctl-cluckn-bell-nonprod-cluster \
  --region us-east-1 \
  --profile cluckin-bell-qa

# Delete failed stack
eksctl delete cluster --name cluckn-bell-nonprod --region us-east-1

# Retry creation
make eks-create ENV=nonprod REGION=us-east-1
```

#### Issue: Route53 health check failing

**Symptoms**:
- Health check status shows "Unhealthy"
- DNS failover not triggering

**Solution**:
```bash
# Get health check details
aws route53 get-health-check-status --health-check-id <id>

# Verify endpoint is accessible
curl -I https://api.cluckn-bell.com/health

# Update health check configuration if needed
aws route53 update-health-check \
  --health-check-id <id> \
  --health-threshold 2
```

#### Issue: ECR replication not working

**Symptoms**:
- Images not appearing in secondary region

**Solution**:
```bash
# Check replication configuration
aws ecr describe-registry --region us-east-1

# Verify IAM permissions for cross-region replication
# Manually replicate image to test
aws ecr batch-get-image --repository-name cluckin-bell-app \
  --region us-east-1 --image-ids imageTag=latest \
  | jq -r '.images[0].imageManifest' \
  | aws ecr put-image --repository-name cluckin-bell-app \
  --region us-west-2 --image-tag latest --image-manifest -
```

### Support Contacts

- **Infrastructure Team**: infrastructure@cluckn-bell.com
- **On-Call**: oncall@cluckn-bell.com
- **AWS Support**: Access via AWS Console

### Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [eksctl Documentation](https://eksctl.io/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Internal Confluence](https://confluence.cluckn-bell.com/infrastructure)

---

**Last Updated**: 2025-12-17
**Document Owner**: Infrastructure Team
**Review Cadence**: Quarterly
