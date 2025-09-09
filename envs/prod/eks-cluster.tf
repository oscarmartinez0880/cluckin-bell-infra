# EKS Cluster Configuration
# This file creates the EKS cluster using the unified network configuration

module "eks" {
  source = "../../modules/eks"

  cluster_name                             = local.cluster_name
  cluster_version                          = "1.30"
  subnet_ids                               = local.all_subnet_ids
  private_subnet_ids                       = local.private_subnet_ids
  public_access_cidrs                      = var.public_access_cidrs
  cloudwatch_log_group_retention_in_days   = var.cluster_log_retention_days

  # Node group configuration for default module node group
  # (We'll create additional explicit node groups in node-groups.tf)
  instance_types = ["t3.medium"]
  desired_size   = 1  # Minimal size for default node group
  min_size       = 1
  max_size       = 2

  tags = local.common_tags

  depends_on = [
    null_resource.validate_existing_subnets
  ]
}