# Conditional VPC Creation Implementation

This document describes the implementation of conditional VPC creation functionality that reintroduces PR 43 capabilities with improved VPC discovery and creation logic.

## Overview

The implementation allows Terraform to:
- **Discover and use existing VPCs** without recreation when a VPC with the expected name exists
- **Create new VPCs** when missing and `create_vpc_if_missing = true`
- **Provide a single source of truth** for VPC ID and subnet IDs to all downstream resources

## Key Features

### 1. VPC Discovery Logic
```hcl
# Discover VPC by name
data "aws_vpcs" "candidate" {
  tags = { Name = local.vpc_name_or_default }
}

# Get VPC details if found
data "aws_vpc" "selected" {
  count = length(data.aws_vpcs.candidate.ids) > 0 ? 1 : 0
  id    = data.aws_vpcs.candidate.ids[0]
}
```

### 2. Conditional VPC Creation
```hcl
# Create VPC only when missing AND creation is enabled
module "vpc" {
  count  = (!local.vpc_exists && var.create_vpc_if_missing) ? 1 : 0
  source = "./modules_new/vpc"
  # ... configuration
}
```

### 3. Single Source of Truth
```hcl
locals {
  vpc_id             = local.vpc_exists ? data.aws_vpc.selected[0].id : module.vpc[0].vpc_id
  private_subnet_ids = local.vpc_exists ? data.aws_subnets.private[0].ids : module.vpc[0].private_subnet_ids
  public_subnet_ids  = local.vpc_exists ? data.aws_subnets.public[0].ids : module.vpc[0].public_subnet_ids
}
```

## Configuration Variables

### Required Variables
- `create_vpc_if_missing` (bool, default: true) - Controls VPC creation when missing
- `vpc_cidr` (string, default: "10.0.0.0/16") - CIDR for new VPC creation

### Optional Variables  
- `vpc_name` (string, default: null) - Override VPC name for discovery (defaults to "{environment}-vpc")
- `public_subnet_cidrs` (list, default: []) - Custom public subnet CIDRs (auto-calculated if empty)
- `private_subnet_cidrs` (list, default: []) - Custom private subnet CIDRs (auto-calculated if empty)

## VPC Module Requirements ✅

The `modules_new/vpc` module meets all specified requirements:

- ✅ **DNS Support**: `enable_dns_hostnames = true`, `enable_dns_support = true`
- ✅ **Subnets**: 3 public + 3 private subnets across 3 AZs in us-east-1
- ✅ **Networking**: Internet Gateway + single NAT Gateway for cost optimization
- ✅ **Route Tables**: Proper public/private route tables and associations
- ✅ **Kubernetes Tags**: 
  - Public subnets: `kubernetes.io/role/elb = "1"`
  - Private subnets: `kubernetes.io/role/internal-elb = "1"`
- ✅ **Standard Tags**: Environment, Project ("cluckin-bell"), ManagedBy ("terraform")

## Usage Examples

### Example 1: Create VPC if Missing (Default)
```hcl
environment = "dev"
create_vpc_if_missing = true  # default
vpc_cidr = "10.0.0.0/16"
```

### Example 2: Require Existing VPC
```hcl
environment = "prod" 
create_vpc_if_missing = false  # Will fail if "prod-vpc" doesn't exist
```

### Example 3: Custom VPC Name
```hcl
environment = "dev"
vpc_name = "my-custom-vpc-name"  # Override default "dev-vpc"
create_vpc_if_missing = true
```

### Example 4: Custom Subnet CIDRs
```hcl
environment = "qa"
vpc_cidr = "10.1.0.0/16"
public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
```

## Validation Scenarios

### Scenario 1: No Existing VPC
- **Input**: `environment = "dev"`, `create_vpc_if_missing = true`
- **Expected**: VPC creation via `modules_new/vpc`, subnets, IGW/NAT/RTs
- **Result**: Downstream components use `local.vpc_id` and subnet IDs from module

### Scenario 2: Existing VPC (Properly Tagged)
- **Input**: VPC exists with `Name = "dev-vpc"` tag
- **Expected**: No VPC/module creations; discovery and reuse
- **Result**: Downstream components use `local.vpc_id` and subnet IDs from data sources

### Scenario 3: Missing VPC + Creation Disabled  
- **Input**: `create_vpc_if_missing = false`, no existing VPC
- **Expected**: Terraform plan/apply fails due to missing VPC
- **Result**: Infrastructure deployment prevented (safety mechanism)

## Route53 Integration ✅

The Route53 private zone correctly uses `local.vpc_id`:
```hcl
# route53.tf
resource "aws_route53_zone" "private" {
  name = "cluckn-bell.com"
  vpc {
    vpc_id = local.vpc_id  # ✅ Uses single source of truth
  }
}
```

## Compatibility

- ✅ **Terraform Version**: 1.7.5 (as specified in .terraform-version)
- ✅ **Existing tfvars**: All existing configuration files remain compatible
- ✅ **Existing Resources**: No changes to working functionality
- ✅ **Route53 Management**: Respects existing `manage_route53` toggle (PR 46)

## Testing

The implementation has been validated with:
- ✅ Terraform syntax validation (`terraform validate`)
- ✅ Format checking (`terraform fmt`)
- ✅ All existing tfvars file compatibility
- ✅ Logical structure verification

## Migration Notes

### For Existing Deployments
1. **No Action Required**: Existing deployments will continue using discovered VPCs
2. **Import Option**: Can import existing VPCs into Terraform state if desired
3. **Gradual Migration**: Can enable conditional creation incrementally per environment

### For New Deployments
1. **Default Behavior**: VPCs will be created automatically if missing
2. **Customization**: Use configuration variables to customize VPC and subnet CIDRs
3. **Safety**: Set `create_vpc_if_missing = false` for environments requiring existing VPCs