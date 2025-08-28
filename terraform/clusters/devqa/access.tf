# Grant cluster-admin in cb-use1-shared to the two deploy roles
provider "aws" {
  alias  = "devqa"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {
  provider = aws.devqa
}

locals {
  role_arns = {
    dev = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cb-eks-deploy-dev"
    qa  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cb-eks-deploy-qa"
  }
}

# Ensure module.eks exists in this stack (from main.tf)
resource "aws_eks_access_entry" "deploy_dev" {
  provider      = aws.devqa
  cluster_name  = module.eks.cluster_name
  principal_arn = local.role_arns.dev
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "deploy_dev_admin" {
  provider      = aws.devqa
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = local.role_arns.dev
  access_scope { type = "cluster" }
}

resource "aws_eks_access_entry" "deploy_qa" {
  provider      = aws.devqa
  cluster_name  = module.eks.cluster_name
  principal_arn = local.role_arns.qa
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "deploy_qa_admin" {
  provider      = aws.devqa
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = local.role_arns.qa
  access_scope { type = "cluster" }
}