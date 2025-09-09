# Explicit managed node group for prod cluster #
resource "aws_eks_node_group" "prod" {
  cluster_name    = module.eks.cluster_name              # Ensure module name matches eks-cluster.tf #
  node_group_name = "prod"
  node_role_arn   = aws_iam_role.eks_node_group.arn      # Uses new IAM role #
  subnet_ids      = local.private_subnet_ids

  scaling_config {
    min_size     = var.prod_node_group_sizes.min
    desired_size = var.prod_node_group_sizes.desired
    max_size     = var.prod_node_group_sizes.max
  }

  instance_types = var.prod_node_group_instance_types
  capacity_type  = "ON_DEMAND"

  labels = { env = "prod" }

  tags = merge(local.common_tags, {
    Name        = "prod-ng"
    Environment = "prod"
  })

  depends_on = [
    module.eks,
    aws_iam_role.eks_node_group
  ]
}

output "prod_node_group" {
  value = aws_eks_node_group.prod.node_group_name
}