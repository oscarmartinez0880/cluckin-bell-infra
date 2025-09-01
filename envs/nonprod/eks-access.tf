locals {
  enable_admin_access = var.sso_admin_role_arn != ""
}

resource "aws_eks_access_entry" "sso_admin" {
  count        = local.enable_admin_access ? 1 : 0
  cluster_name = module.eks.cluster_name

  principal_arn = var.sso_admin_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "sso_admin_cluster_admin" {
  count        = local.enable_admin_access ? 1 : 0
  cluster_name = module.eks.cluster_name
  policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  principal_arn = var.sso_admin_role_arn
  access_scope { type = "cluster" }
}