# Additional EKS Deploy Role for Prod with specific naming for cb-eks-deploy pattern
# This complements the existing GH_EKS_Deploy_* role in main.tf

locals {
  # Additional role following cb-eks-deploy-* naming pattern
  github_owner = "oscarmartinez0880"
  github_repo  = "cluckin-bell"
  sub_pattern  = "repo:${local.github_owner}/${local.github_repo}:*"
}

data "aws_iam_policy_document" "cb_deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.sub_pattern]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cb_eks_deploy_policy" {
  statement {
    sid    = "EksReadCluster"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:ListClusters"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cb_eks_deploy" {
  provider = aws.prod
  name     = "cb-eks-deploy-minimal"
  policy   = data.aws_iam_policy_document.cb_eks_deploy_policy.json

  tags = merge(var.tags, {
    Name    = "cb-eks-deploy-minimal"
    Purpose = "cb-eks-deploy"
  })
}

resource "aws_iam_role" "cb_eks_deploy_prod" {
  provider           = aws.prod
  name               = "cb-eks-deploy-prod"
  assume_role_policy = data.aws_iam_policy_document.cb_deploy_trust.json

  tags = merge(var.tags, {
    Name        = "cb-eks-deploy-prod"
    Environment = "prod"
    Purpose     = "cb-eks-deploy"
  })
}

resource "aws_iam_role_policy_attachment" "cb_eks_deploy_prod_attach" {
  provider   = aws.prod
  role       = aws_iam_role.cb_eks_deploy_prod.name
  policy_arn = aws_iam_policy.cb_eks_deploy.arn
}

output "cb_eks_deploy_prod_role_arn" {
  value = aws_iam_role.cb_eks_deploy_prod.arn
}