# Network Configuration - VPC and Subnet Selection
# This file handles the logic for choosing between creating new VPC/subnets
# or reusing existing ones based on the configuration variables.

# Data sources for eksctl-managed cluster
# These allow Terraform to reference the existing cluster for IRSA and provider configuration
data "aws_eks_cluster" "existing" {
  name = var.cluster_name != "" ? var.cluster_name : "cluckn-bell-nonprod"
}

data "aws_eks_cluster_auth" "existing" {
  name = var.cluster_name != "" ? var.cluster_name : "cluckn-bell-nonprod"
}

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
  cluster_name = var.cluster_name != "" ? var.cluster_name : "cluckn-bell-nonprod"

  # Cluster attributes from eksctl-managed cluster
  # These will fail if the cluster doesn't exist yet - that's expected during initial VPC setup
  cluster_endpoint                   = try(data.aws_eks_cluster.existing.endpoint, "")
  cluster_arn                        = try(data.aws_eks_cluster.existing.arn, "")
  cluster_id                         = try(data.aws_eks_cluster.existing.id, "")
  cluster_oidc_issuer_url            = try(data.aws_eks_cluster.existing.identity[0].oidc[0].issuer, "")
  cluster_certificate_authority_data = try(data.aws_eks_cluster.existing.certificate_authority[0].data, "")

  # Construct OIDC provider ARN for eksctl-managed cluster
  cluster_oidc_provider_arn = local.cluster_oidc_issuer_url != "" ? "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(local.cluster_oidc_issuer_url, "https://", "")}" : ""
}

# Conditional VPC creation - only create if not using existing VPC
module "vpc" {
  count  = local.use_existing_vpc ? 0 : 1
  source = "../../modules/vpc"

  name                 = "cluckn-bell-nonprod"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

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