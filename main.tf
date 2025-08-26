# Main infrastructure configuration

# Local values for consistent resource naming and tagging
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge(var.common_tags, {
    Environment = var.environment
  })
}

# TODO: Add your infrastructure resources here
# This is a placeholder - replace with your actual infrastructure

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