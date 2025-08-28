# Grant cluster-admin in cb-use1-prod to the prod deploy role
provider "aws" {
  alias  = "prod"
  region = "us-east-1"
}

data "aws_caller_identity" "current" {
  provider = aws.prod
}

locals {
  role_arn_prod = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cb-eks-deploy-prod"
}

resource "aws_eks_access_entry" "deploy_prod" {
  provider      = aws.prod
  cluster_name  = module.eks.cluster_name
  principal_arn = local.role_arn_prod
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "deploy_prod_admin" {
  provider      = aws.prod
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = local.role_arn_prod
  access_scope { type = "cluster" }
}