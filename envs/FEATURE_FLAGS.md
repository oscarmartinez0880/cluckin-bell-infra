# Infrastructure Feature Flags

This document describes the feature flags used to control cost-sensitive infrastructure components in both `nonprod` and `prod` environments.

## Overview

By default, the infrastructure is configured in a **minimal and cost-safe mode**. This prevents accidental provisioning of expensive resources while allowing easy re-enablement when needed.

## Feature Flags

All feature flags are boolean variables that can be set in your `.tfvars` file or via command-line arguments.

### `enable_dns` (default: `true`)
- **Controls:** Route53 hosted zones and ACM certificates
- **Cost Impact:** Minimal (~$0.50/month per hosted zone)
- **Default:** `true` - Route53 costs are acceptable per user requirements
- **Notes:** In nonprod, private zones are not created to avoid additional costs

### `enable_ecr` (default: `false`)
- **Controls:** ECR container repositories
- **Cost Impact:** Storage costs for container images (~$0.10/GB/month)
- **Default:** `false` - Disabled to prevent storage costs
- **Dependencies:** None

### `enable_monitoring` (default: `false`)
- **Controls:** CloudWatch log groups, Container Insights, monitoring agents
- **Cost Impact:** Log storage, Container Insights data, agent compute
- **Default:** `false` - Disabled to prevent monitoring costs
- **Dependencies:** Requires `enable_irsa=true` if using CloudWatch agents
- **Notes:** Log retention set to 1 day minimum when enabled

### `enable_irsa` (default: `false`)
- **Controls:** All IRSA (IAM Roles for Service Accounts) roles including:
  - AWS Load Balancer Controller
  - External DNS (dev and qa in nonprod)
  - Cluster Autoscaler
  - Fluent Bit
  - CloudWatch Agent
  - External Secrets
  - Cert Manager
- **Cost Impact:** No direct cost, but roles are useless without EKS cluster
- **Default:** `false` - Requires EKS cluster with OIDC provider
- **Dependencies:** 
  - **REQUIRED:** EKS cluster to exist
  - **REQUIRED:** `enable_dns=true` (IRSA modules reference DNS zone IDs)
- **Validation:** Terraform will fail with an error if `enable_irsa=true` and `enable_dns=false`

### `enable_cognito` (default: `false`)
- **Controls:** Cognito user pools and clients
- **Cost Impact:** User pool costs (~$0.0055 per MAU after free tier)
- **Default:** `false` - Disabled to prevent user pool costs
- **Dependencies:** None

### `enable_github_oidc` (default: `false`)
- **Controls:** GitHub OIDC provider role for ECR push
- **Cost Impact:** No direct cost (IAM role only)
- **Default:** `false` - Disabled by default
- **Dependencies:** 
  - **REQUIRED:** `enable_ecr=true` (references ECR repository ARNs)
- **Validation:** Terraform will fail with an error if `enable_github_oidc=true` and `enable_ecr=false`

### `enable_secrets` (default: `false`)
- **Controls:** AWS Secrets Manager secrets
- **Cost Impact:** ~$0.40/month per secret + API call costs
- **Default:** `false` - Disabled to prevent per-secret costs
- **Dependencies:** None

### `enable_alerting` (default: `false`)
- **Controls:** SNS topics, CloudWatch alarms, alerting infrastructure
- **Cost Impact:** SNS message delivery, CloudWatch alarm costs
- **Default:** `false` - Disabled to prevent alerting costs
- **Dependencies:** None

## Usage Examples

### Minimal Mode (Default)
```hcl
# No variables needed - all defaults to minimal mode
# Only DNS is enabled by default
```

### Enable ECR and GitHub Actions Push
```hcl
enable_ecr = true
enable_github_oidc = true
```

### Enable Full Monitoring Stack
```hcl
enable_dns = true        # Already default
enable_irsa = true       # Required for agents
enable_monitoring = true # Enables Container Insights
```

### Enable All Features
```hcl
enable_dns = true
enable_ecr = true
enable_monitoring = true
enable_irsa = true
enable_cognito = true
enable_github_oidc = true
enable_secrets = true
enable_alerting = true
```

## Migration Guide

### Enabling Features on Existing Infrastructure

1. **Plan First:** Always run `terraform plan` before applying changes
   ```bash
   terraform plan -var="enable_ecr=true"
   ```

2. **Enable Dependencies First:** Some features depend on others
   - Enable `enable_ecr` before `enable_github_oidc`
   - Enable `enable_irsa` before `enable_monitoring` (if using agents)
   - Enable `enable_dns` is already on by default

3. **Apply Changes:** Once plan looks correct
   ```bash
   terraform apply -var="enable_ecr=true"
   ```

### Disabling Features

Simply set the flag to `false` and run `terraform apply`. Resources will be destroyed.

**WARNING:** Some resources (like ECR with images, Secrets Manager secrets, Cognito user pools) may contain data. Review the plan carefully before applying.

## Environment-Specific Notes

### Nonprod Environment
- Private Route53 zones are not created (`private_zone.create = false`)
- Uses existing public zones: `dev.cluckn-bell.com` and `qa.cluckn-bell.com`
- Minimal log retention (1 day)

### Prod Environment
- Internal private zone `internal.cluckn-bell.com` not created by default (`create_internal_zone = false`)
- Uses existing public zone: `cluckn-bell.com`
- Minimal log retention (1 day) - increase if needed in production
- Zone deletion protection enabled (`allow_zone_destroy = false`)

## Cost Estimates

### Minimal Mode (Defaults)
- **Route53:** ~$0.50/month per hosted zone
- **VPC:** ~$0-5/month (NAT Gateway if enabled separately)
- **Total:** ~$1-10/month depending on DNS zones

### Full Mode (All Features Enabled)
- **Route53:** ~$0.50/month per zone
- **ECR:** Variable (depends on image storage)
- **Monitoring:** ~$30-100/month (Container Insights, logs)
- **Secrets Manager:** ~$0.40/month per secret × number of secrets
- **Cognito:** ~$0.0055 per MAU after free tier
- **SNS/Alarms:** ~$1-10/month
- **Total:** ~$50-200+/month depending on usage

## Validation Rules

The infrastructure includes automatic validation at the variable level to prevent misconfiguration:

1. **IRSA requires DNS:** If `enable_irsa=true`, then `enable_dns` must also be `true`
   - Reason: IRSA modules for external-dns and cert-manager reference DNS zone IDs
   - Validation: Variable-level check in `enable_irsa` definition
   
2. **GitHub OIDC requires ECR:** If `enable_github_oidc=true`, then `enable_ecr` must also be `true`
   - Reason: GitHub OIDC role references ECR repository ARNs
   - Validation: Variable-level check in `enable_github_oidc` definition

These validations will cause Terraform to fail **immediately** during init/plan/apply with a clear error message if violated, before any resources are created or modified.

## Troubleshooting

### Error: enable_dns must be true when enable_irsa is true
You're trying to enable IRSA without DNS. Enable DNS first:
```hcl
enable_dns = true   # Required
enable_irsa = true
```

### Error: enable_ecr must be true when enable_github_oidc is true
You're trying to enable GitHub OIDC without ECR. Enable ECR first:
```hcl
enable_ecr = true          # Required
enable_github_oidc = true
```

### Error: Can't access attributes on a list of objects
This means you're trying to reference a module output that's conditionally created. Update your references to use the `[0]` syntax:
```hcl
# Before
module.ecr.repository_arns

# After
var.enable_ecr ? module.ecr[0].repository_arns : {}
```

### Error: OIDC provider not found
You're trying to enable IRSA roles without an EKS cluster. Either:
1. Create the EKS cluster first using `eksctl`
2. Keep `enable_irsa = false` until the cluster exists

### Error: ECR repository not found (GitHub OIDC)
Enable ECR first:
```hcl
enable_ecr = true
enable_github_oidc = true
```

## Additional Resources

- See `envs/nonprod/variables.tf` and `envs/prod/variables.tf` for variable definitions
- See `envs/nonprod/main.tf` and `envs/prod/main.tf` for module implementation
- See module-specific documentation in `modules/*/README.md`
