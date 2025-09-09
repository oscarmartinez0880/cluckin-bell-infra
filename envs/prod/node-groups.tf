# EKS Node Groups Configuration - Production Environment
# This file creates explicit node groups for production environment

# Production Environment Node Group
resource "aws_eks_node_group" "prod" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "prod"
  node_role_arn   = module.eks.node_group_role_arn
  subnet_ids      = local.private_subnet_ids

  capacity_type  = "ON_DEMAND"
  instance_types = var.prod_node_group_instance_types

  scaling_config {
    desired_size = var.prod_node_group_desired_size
    max_size     = var.prod_node_group_max_size
    min_size     = var.prod_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    Environment = "prod"
    NodeGroup   = "prod"
  }

  tags = merge(local.common_tags, {
    Name        = "${local.cluster_name}-prod-node-group"
    Environment = "prod"
  })

  depends_on = [module.eks]
}