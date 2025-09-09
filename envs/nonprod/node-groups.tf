# EKS Node Groups Configuration - Nonprod Environment
# This file creates explicit node groups for dev and qa environments

# Dev Environment Node Group
resource "aws_eks_node_group" "dev" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "dev"
  node_role_arn   = module.eks.node_group_role_arn
  subnet_ids      = local.private_subnet_ids

  capacity_type  = "ON_DEMAND"
  instance_types = var.dev_node_group_instance_types

  scaling_config {
    desired_size = var.dev_node_group_desired_size
    max_size     = var.dev_node_group_max_size
    min_size     = var.dev_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    Environment = "dev"
    NodeGroup   = "dev"
  }

  tags = merge(local.common_tags, {
    Name        = "${local.cluster_name}-dev-node-group"
    Environment = "dev"
  })

  depends_on = [module.eks]
}

# QA Environment Node Group
resource "aws_eks_node_group" "qa" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "qa"
  node_role_arn   = module.eks.node_group_role_arn
  subnet_ids      = local.private_subnet_ids

  capacity_type  = "ON_DEMAND"
  instance_types = var.qa_node_group_instance_types

  scaling_config {
    desired_size = var.qa_node_group_desired_size
    max_size     = var.qa_node_group_max_size
    min_size     = var.qa_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    Environment = "qa"
    NodeGroup   = "qa"
  }

  tags = merge(local.common_tags, {
    Name        = "${local.cluster_name}-qa-node-group"
    Environment = "qa"
  })

  depends_on = [module.eks]
}