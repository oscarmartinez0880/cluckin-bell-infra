module "eks" {
  count  = var.create_eks ? 1 : 0
  source = "../../modules/eks"

  cluster_name                           = local.cluster_name
  cluster_version                        = "1.34"
  subnet_ids                             = local.all_subnet_ids
  private_subnet_ids                     = local.private_subnet_ids
  public_access_cidrs                    = var.public_access_cidrs
  cloudwatch_log_group_retention_in_days = var.cluster_log_retention_days

  create_default_node_group = false # NEW - disables internal node group #

  instance_types = ["t3.small"]
  desired_size   = 0
  min_size       = 0
  max_size       = 0

  tags = local.common_tags

  depends_on = [
    null_resource.validate_existing_subnets
  ]
}

# Data sources for existing eksctl-managed cluster (when create_eks = false)
data "aws_eks_cluster" "existing" {
  count = var.create_eks ? 0 : 1
  name  = local.cluster_name
}

data "aws_eks_cluster_auth" "existing" {
  count = var.create_eks ? 0 : 1
  name  = local.cluster_name
}