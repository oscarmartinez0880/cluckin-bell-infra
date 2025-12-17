# Disaster Recovery Implementation Guide

This guide provides step-by-step instructions for configuring and using the new DR capabilities in the cluckin-bell-infra repository.

## Prerequisites

Before enabling DR features, ensure you have:

1. **Repository Variables Configured** (required for GitHub Actions)
2. **AWS SSO Access** to both accounts
3. **Secondary Region Infrastructure** (if enabling DNS failover)

## Step 1: Configure Repository Variables

Navigate to: `https://github.com/oscarmartinez0880/cluckin-bell-infra/settings/variables/actions`

Click "New repository variable" and add each of the following:

| Variable Name | Value (Example) | Description |
|---------------|-----------------|-------------|
| `AWS_TERRAFORM_ROLE_ARN_QA` | `arn:aws:iam::264765154707:role/github-actions-terraform` | Terraform role for nonprod account |
| `AWS_TERRAFORM_ROLE_ARN_PROD` | `arn:aws:iam::346746763840:role/github-actions-terraform` | Terraform role for prod account |
| `AWS_EKSCTL_ROLE_ARN_QA` | `arn:aws:iam::264765154707:role/github-actions-eksctl` | eksctl role for nonprod account |
| `AWS_EKSCTL_ROLE_ARN_PROD` | `arn:aws:iam::346746763840:role/github-actions-eksctl` | eksctl role for prod account |

### Finding Your Role ARNs

If you don't know your role ARNs, run:

```bash
# For nonprod account
aws sso login --profile cluckin-bell-qa
export AWS_PROFILE=cluckin-bell-qa
cd terraform/accounts/devqa
terraform output

# For prod account
aws sso login --profile cluckin-bell-prod
export AWS_PROFILE=cluckin-bell-prod
cd terraform/accounts/prod
terraform output
```

## Step 2: Test GitHub Actions Workflows

Once repository variables are configured, test the workflows:

### Test Infrastructure Deployment

1. Go to: Actions → **Infrastructure Terraform**
2. Click "Run workflow"
3. Select:
   - Environment: `nonprod`
   - Working Directory: `envs/nonprod`
   - Action: `plan`
4. Click "Run workflow"
5. Check the job runs successfully

### Test EKS Cluster Workflow

1. Go to: Actions → **EKS Cluster Management**
2. Click "Run workflow"
3. Select:
   - Environment: `nonprod`
   - Action: `create` (Note: This won't actually create if cluster exists)
4. Click "Run workflow"

## Step 3: Enable DR Features (Optional)

DR features are disabled by default. Enable them based on your needs:

### Option A: Via Terraform (Recommended for Production)

Create `envs/prod/dr-override.auto.tfvars`:

```hcl
# Enable ECR replication to us-west-2
enable_ecr_replication   = true
ecr_replication_regions  = ["us-west-2"]

# Enable Secrets replication (requires configuring secrets in main.tf)
enable_secrets_replication   = false
secrets_replication_regions  = []

# Enable DNS failover (requires secondary region infrastructure)
enable_dns_failover = false
failover_records = {}
```

Then apply:

```bash
cd envs/prod
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### Option B: Via GitHub Actions

1. Go to: Actions → **DR Launch Production**
2. Click "Run workflow"
3. Configure:
   - DR Region: `us-west-2`
   - Enable ECR replication: ✓
   - Enable Secrets replication: (only if secrets configured)
   - Enable DNS failover: (only if secondary infrastructure exists)
4. Click "Run workflow"

### Option C: Via Makefile

```bash
# SSO login first
make sso-prod

# Provision DR in us-west-2
make dr-provision-prod REGION=us-west-2

# Check status
make dr-status-prod
```

## Step 4: Configure Secrets Replication (Optional)

If you want to replicate secrets:

1. Edit `envs/prod/main.tf`
2. Find the `module "secrets_replication"` section
3. Replace the empty `secrets = {}` with your secrets:

```hcl
module "secrets_replication" {
  count  = var.enable_secrets && var.enable_secrets_replication && length(var.secrets_replication_regions) > 0 ? 1 : 0
  source = "../../modules/secrets"

  secrets = {
    "prod/database/master" = {
      description      = "Master database credentials"
      static_values    = { username = "dbadmin" }
      generated_values = { password = "" }
    }
    "prod/api/keys" = {
      description      = "API keys"
      static_values    = { api_url = "https://api.cluckn-bell.com" }
      generated_values = { api_key = "" }
    }
  }
  
  enable_replication  = true
  replication_regions = var.secrets_replication_regions

  tags = merge(local.common_tags, {
    Service = "secrets-dr"
  })
}
```

4. Apply changes:

```bash
cd envs/prod
terraform apply
```

## Step 5: Configure DNS Failover (Optional)

If you have infrastructure in a secondary region:

1. Edit `envs/prod/dr-override.auto.tfvars`
2. Add failover records:

```hcl
enable_dns_failover = true

failover_records = {
  argocd = {
    hostname           = "argocd.cluckn-bell.com"
    primary_endpoint   = "prod-argocd-alb-12345.us-east-1.elb.amazonaws.com"
    secondary_endpoint = "prod-argocd-alb-67890.us-west-2.elb.amazonaws.com"
    health_check_path  = "/healthz"
    health_check_port  = 443
  }
  api = {
    hostname           = "api.cluckn-bell.com"
    primary_endpoint   = "prod-api-alb-11111.us-east-1.elb.amazonaws.com"
    secondary_endpoint = "prod-api-alb-22222.us-west-2.elb.amazonaws.com"
    health_check_path  = "/health"
    health_check_port  = 443
  }
}
```

3. Apply:

```bash
cd envs/prod
terraform apply
```

## Step 6: Verify DR Configuration

After enabling DR features, verify they're working:

```bash
cd envs/prod
terraform init -backend-config=backend.hcl

# Check DR outputs
terraform output dr_ecr_replication_regions
terraform output dr_secrets_replication_regions
terraform output dr_dns_failover_enabled
terraform output dr_dns_failover_health_checks
```

Or via Makefile:

```bash
make dr-status-prod
```

## Cost Estimation

Approximate monthly costs for DR features:

| Feature | Cost |
|---------|------|
| ECR Replication (1TB) | ~$100 (storage + data transfer) |
| Secrets Replication (5 secrets) | $2.00 |
| DNS Failover (2 health checks) | $1.00 |
| **Total** | **~$103/month** |

**Note:** ECR replication cost varies significantly based on image count and size. Start with a small subset of critical images.

## Rollback Procedure

If you need to disable DR features:

1. Edit `envs/prod/dr-override.auto.tfvars`:

```hcl
enable_ecr_replication      = false
enable_secrets_replication  = false
enable_dns_failover         = false
```

2. Apply:

```bash
cd envs/prod
terraform apply
```

3. Terraform will remove all DR resources.

## Troubleshooting

### Workflow fails with "vars.AWS_TERRAFORM_ROLE_ARN_QA is empty"

- Verify repository variables are configured in GitHub Settings
- Ensure variable names match exactly (case-sensitive)

### ECR replication not working

- Check account-level replication configuration:
  ```bash
  aws ecr describe-registry --region us-east-1 | jq .replicationConfiguration
  ```
- Verify destination region is correct
- Check IAM permissions for ECR replication

### Secrets replication fails

- Ensure secrets exist before enabling replication
- Check KMS key permissions in destination region
- Verify replica block is properly configured

### DNS failover health checks failing

- Verify endpoint URLs are accessible from AWS health check IPs
- Check HTTPS certificates are valid
- Ensure health check path returns 200 status

## Next Steps

1. ✅ Configure repository variables
2. ✅ Test GitHub Actions workflows
3. 🔄 Enable ECR replication (recommended)
4. 🔄 Configure secrets replication (optional)
5. 🔄 Set up DNS failover (optional, requires secondary region)
6. 📊 Monitor DR resources via CloudWatch
7. 🧪 Test DR failover procedures

## Support

For issues or questions:
- Check workflow logs in GitHub Actions
- Review Terraform outputs: `terraform output`
- Consult README.md for detailed documentation
