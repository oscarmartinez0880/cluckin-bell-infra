resource "aws_eks_node_group" "dev" {
  cluster_name    = module.eks_nonprod.cluster_name
  node_group_name = "dev"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    min_size     = var.dev_node_group_sizes.min
    desired_size = var.dev_node_group_sizes.desired
    max_size     = var.dev_node_group_sizes.max
  }

  instance_types = var.dev_node_group_instance_types
  capacity_type  = "ON_DEMAND"

  labels = { env = "dev" }

  tags = {
    Name        = "nonprod-dev-ng"
    Environment = "dev"
    Project     = "cluckin-bell"
  }

  depends_on = [module.eks_nonprod, aws_iam_role.eks_node_group]
}

resource "aws_eks_node_group" "qa" {
  cluster_name    = module.eks_nonprod.cluster_name
  node_group_name = "qa"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    min_size     = var.qa_node_group_sizes.min
    desired_size = var.qa_node_group_sizes.desired
    max_size     = var.qa_node_group_sizes.max
  }

  instance_types = var.qa_node_group_instance_types
  capacity_type  = "ON_DEMAND"

  labels = { env = "qa" }

  tags = {
    Name        = "nonprod-qa-ng"
    Environment = "qa"
    Project     = "cluckin-bell"
  }

  depends_on = [module.eks_nonprod, aws_iam_role.eks_node_group]
}

output "nonprod_node_groups" {
  value = {
    dev = aws_eks_node_group.dev.node_group_name
    qa  = aws_eks_node_group.qa.node_group_name
  }
}