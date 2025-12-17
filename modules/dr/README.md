# Disaster Recovery Module

This module provides optional disaster recovery capabilities for the Cluckin Bell infrastructure. All features are disabled by default and can be enabled selectively.

## Features

### 1. ECR Cross-Region Replication

Automatically replicates container images from ECR to one or more target regions for disaster recovery.

**Usage:**
```hcl
module "dr" {
  source = "../../modules/dr"

  enable_ecr_replication  = true
  ecr_replication_regions = ["us-west-2", "eu-west-1"]
}
```

### 2. Secrets Manager Replication

Replicates AWS Secrets Manager secrets to target regions for multi-region deployments.

**Usage:**
```hcl
module "dr" {
  source = "../../modules/dr"

  enable_secrets_replication  = true
  secrets_replication_regions = ["us-west-2"]
  secret_ids = [
    "arn:aws:secretsmanager:us-east-1:123456789012:secret:my-secret",
    "/cluckn-bell/app/database-password"
  ]
}
```

### 3. Route53 DNS Failover

Creates Route53 health checks and failover DNS records for automatic failover between primary and secondary endpoints.

**Usage:**
```hcl
module "dr" {
  source = "../../modules/dr"

  enable_dns_failover = true
  hosted_zone_id      = "Z1234567890ABC"
  
  failover_records = {
    "api" = {
      name               = "api.cluckn-bell.com"
      type               = "A"
      primary_endpoint   = "api-primary.us-east-1.elb.amazonaws.com"
      secondary_endpoint = "api-secondary.us-west-2.elb.amazonaws.com"
      health_check_path  = "/health"
    }
  }
}
```

## Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `enable_ecr_replication` | Enable ECR cross-region replication | `bool` | `false` |
| `ecr_replication_regions` | Target regions for ECR replication | `list(string)` | `[]` |
| `enable_secrets_replication` | Enable Secrets Manager replication | `bool` | `false` |
| `secrets_replication_regions` | Target regions for secrets replication | `list(string)` | `[]` |
| `secret_ids` | List of secret IDs/ARNs to replicate | `list(string)` | `[]` |
| `enable_dns_failover` | Enable Route53 DNS failover | `bool` | `false` |
| `failover_records` | Map of DNS failover configurations | `map(object)` | `{}` |
| `hosted_zone_id` | Route53 hosted zone ID | `string` | `""` |
| `tags` | Tags to apply to resources | `map(string)` | `{}` |

## Outputs

- `ecr_replication_enabled`: Whether ECR replication is enabled
- `ecr_replication_regions`: List of regions where ECR images are replicated
- `secrets_replication_enabled`: Whether secrets replication is enabled
- `secrets_replication_regions`: List of regions where secrets are replicated
- `dns_failover_enabled`: Whether DNS failover is enabled
- `primary_health_check_ids`: Map of primary health check IDs
- `secondary_health_check_ids`: Map of secondary health check IDs

## Cost Considerations

All DR features incur additional AWS costs:

- **ECR Replication**: Storage costs in target regions + data transfer
- **Secrets Replication**: Per-secret replication cost (~$0.40/month per replica)
- **Route53 Health Checks**: ~$0.50/month per health check

Enable only the features you need for your disaster recovery strategy.
