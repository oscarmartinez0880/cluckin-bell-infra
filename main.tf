# Main infrastructure configuration

# Local values for consistent resource naming and tagging
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    Environment = var.environment
  })
}

# CI Runners Module - Windows GitHub Actions runners for Sitecore builds
module "ci_runners" {
  count = var.enable_ci_runners ? 1 : 0

  source = "./modules/ci-runners"

  name_prefix = local.name_prefix
  tags        = local.tags

  # GitHub App configuration
  github_app_id                        = var.ci_runners_github_app_id
  github_app_installation_id           = var.ci_runners_github_app_installation_id
  github_app_private_key_ssm_parameter = var.ci_runners_github_app_private_key_ssm_parameter
  github_repository_allowlist          = var.ci_runners_github_repository_allowlist

  # Instance configuration
  instance_type = var.ci_runners_instance_type
  max_size      = var.ci_runners_max_size

  # Use default settings for other configuration
  # (VPC CIDR, subnets, volumes, etc.)
}

# TODO: Add additional infrastructure resources here
# This is a placeholder - add your other infrastructure as needed

# Example resource block (uncomment and modify as needed):
# resource "aws_vpc" "main" {
#   cidr_block           = "10.0.0.0/16"
#   enable_dns_hostnames = true
#   enable_dns_support   = true
#
#   tags = merge(local.tags, {
#     Name = "${local.name_prefix}-vpc"
#   })
# }

# Example data source (uncomment and modify as needed):
# data "aws_availability_zones" "available" {
#   state = "available"
# }

# Example module usage (uncomment and modify as needed):
# module "eks" {
#   source = "./modules/eks"
#   
#   cluster_name = "${local.name_prefix}-cluster"
#   vpc_id       = aws_vpc.main.id
#   subnet_ids   = aws_subnet.private[*].id
#   
#   tags = local.tags
# }