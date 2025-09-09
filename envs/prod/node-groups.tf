resource "aws_eks_node_group" "prod" {
  cluster_name    = module.eks_prod.cluster_name
  node_group_name = "prod"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    min_size     = var.prod_node_group_sizes.min
    desired_size = var.prod_node_group_sizes.desired
    max_size     = var.prod_node_group_sizes.max
  }

  instance_types = var.prod_node_group_instance_types
  capacity_type  = "ON_DEMAND"

  labels = { env = "prod" }

  tags = {
    Name        = "prod-ng"
    Environment = "prod"
    Project     = "cluckin-bell"
  }

  depends_on = [module.eks_prod, aws_iam_role.eks_node_group]
}

output "prod_node_group" {
  value = aws_eks_node_group.prod.node_group_name
}