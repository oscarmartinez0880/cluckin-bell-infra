# Explicit managed node group for prod cluster #
# Note: This node group is only created when create_eks = true (Terraform-managed cluster)
# For eksctl-managed clusters, node groups are defined in eksctl YAML configs
resource "aws_eks_node_group" "prod" {
  count           = var.create_eks ? 1 : 0
  cluster_name    = module.eks[0].cluster_name
  node_group_name = "prod"
  node_role_arn   = aws_iam_role.eks_node_group.arn # Uses new IAM role #
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
  value = var.create_eks ? aws_eks_node_group.prod[0].node_group_name : ""
}