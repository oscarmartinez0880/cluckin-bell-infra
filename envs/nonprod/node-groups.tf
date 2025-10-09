# UPDATED: References module.eks (not module.eks_nonprod) and uses object variables for sizes #
# Note: These node groups are only created when create_eks = true (Terraform-managed cluster)
# For eksctl-managed clusters, node groups are defined in eksctl YAML configs
resource "aws_eks_node_group" "dev" {
  count           = var.create_eks ? 1 : 0
  cluster_name    = module.eks[0].cluster_name
  node_group_name = "dev"
  node_role_arn   = aws_iam_role.eks_node_group.arn # NEW reference to new IAM role #
  subnet_ids      = local.private_subnet_ids        # Use same private subnets local if available #

  scaling_config {
    min_size     = var.dev_node_group_sizes.min
    desired_size = var.dev_node_group_sizes.desired
    max_size     = var.dev_node_group_sizes.max
  }

  instance_types = var.dev_node_group_instance_types
  capacity_type  = "ON_DEMAND"

  labels = { env = "dev" }

  tags = merge(local.common_tags, {
    Name        = "nonprod-dev-ng"
    Environment = "dev"
  })

  depends_on = [
    module.eks,                 # CHANGED #
    aws_iam_role.eks_node_group # NEW #
  ]
}

resource "aws_eks_node_group" "qa" {
  count           = var.create_eks ? 1 : 0
  cluster_name    = module.eks[0].cluster_name
  node_group_name = "qa"
  node_role_arn   = aws_iam_role.eks_node_group.arn # NEW reference #
  subnet_ids      = local.private_subnet_ids

  scaling_config {
    min_size     = var.qa_node_group_sizes.min
    desired_size = var.qa_node_group_sizes.desired
    max_size     = var.qa_node_group_sizes.max
  }

  instance_types = var.qa_node_group_instance_types
  capacity_type  = "ON_DEMAND"

  labels = { env = "qa" }

  tags = merge(local.common_tags, {
    Name        = "nonprod-qa-ng"
    Environment = "qa"
  })

  depends_on = [
    module.eks,                 # CHANGED #
    aws_iam_role.eks_node_group # NEW #
  ]
}

output "nonprod_node_groups" {
  value = var.create_eks ? {
    dev = aws_eks_node_group.dev[0].node_group_name
    qa  = aws_eks_node_group.qa[0].node_group_name
  } : {}
}