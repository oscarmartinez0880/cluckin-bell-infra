# Network Configuration - VPC and Subnet Selection
# This file handles the logic for choosing between creating new VPC/subnets
# or reusing existing ones based on the configuration variables.

locals {
  # Determine whether to use existing VPC or create new one
  use_existing_vpc = var.existing_vpc_id != ""

  # VPC ID selection
  vpc_id = local.use_existing_vpc ? var.existing_vpc_id : module.vpc[0].vpc_id

  # Subnet ID selection
  public_subnet_ids  = local.use_existing_vpc ? var.public_subnet_ids : module.vpc[0].public_subnet_ids
  private_subnet_ids = local.use_existing_vpc ? var.private_subnet_ids : module.vpc[0].private_subnet_ids

  # Combined subnet IDs for EKS cluster (used by eksctl)
  all_subnet_ids = concat(local.private_subnet_ids, local.public_subnet_ids)

  # Cluster name for eksctl-managed cluster
  cluster_name = var.cluster_name != "" ? var.cluster_name : "cluckn-bell-prod"
}

# Conditional VPC creation - only create if not using existing VPC
module "vpc" {
  count  = local.use_existing_vpc ? 0 : 1
  source = "../../modules/vpc"

  name                 = "cluckn-bell-prod"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  tags = local.common_tags
}

# Validation - ensure we have at least 2 subnets of each type when reusing
resource "null_resource" "validate_existing_subnets" {
  count = local.use_existing_vpc ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(var.public_subnet_ids) >= 2
      error_message = "At least 2 public subnet IDs must be provided when reusing existing VPC."
    }

    precondition {
      condition     = length(var.private_subnet_ids) >= 2
      error_message = "At least 2 private subnet IDs must be provided when reusing existing VPC."
    }

    precondition {
      condition     = var.existing_vpc_id != ""
      error_message = "existing_vpc_id must be provided when reusing existing VPC."
    }
  }
}