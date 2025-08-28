# Additional EKS Deploy Roles with specific naming for cb-eks-deploy pattern
# These complement the existing GH_EKS_Deploy_* roles in main.tf

locals {
  # Additional roles following cb-eks-deploy-* naming pattern
  github_owner = "oscarmartinez0880"
  github_repo  = "cluckin-bell"
  # Allow all refs from this repo (broader than existing environment-scoped roles)
  sub_pattern = "repo:${local.github_owner}/${local.github_repo}:*"
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

# Minimal policy for kubectl via aws eks update-kubeconfig
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
  provider = aws.devqa
  name     = "cb-eks-deploy-minimal"
  policy   = data.aws_iam_policy_document.cb_eks_deploy_policy.json

  tags = merge(var.tags, {
    Name    = "cb-eks-deploy-minimal"
    Purpose = "cb-eks-deploy"
  })
}

# DEV role
resource "aws_iam_role" "cb_eks_deploy_dev" {
  provider           = aws.devqa
  name               = "cb-eks-deploy-dev"
  assume_role_policy = data.aws_iam_policy_document.cb_deploy_trust.json

  tags = merge(var.tags, {
    Name        = "cb-eks-deploy-dev"
    Environment = "dev"
    Purpose     = "cb-eks-deploy"
  })
}

resource "aws_iam_role_policy_attachment" "cb_eks_deploy_dev_attach" {
  provider   = aws.devqa
  role       = aws_iam_role.cb_eks_deploy_dev.name
  policy_arn = aws_iam_policy.cb_eks_deploy.arn
}

# QA role
resource "aws_iam_role" "cb_eks_deploy_qa" {
  provider           = aws.devqa
  name               = "cb-eks-deploy-qa"
  assume_role_policy = data.aws_iam_policy_document.cb_deploy_trust.json

  tags = merge(var.tags, {
    Name        = "cb-eks-deploy-qa"
    Environment = "qa"
    Purpose     = "cb-eks-deploy"
  })
}

resource "aws_iam_role_policy_attachment" "cb_eks_deploy_qa_attach" {
  provider   = aws.devqa
  role       = aws_iam_role.cb_eks_deploy_qa.name
  policy_arn = aws_iam_policy.cb_eks_deploy.arn
}

output "cb_eks_deploy_dev_role_arn" {
  value = aws_iam_role.cb_eks_deploy_dev.arn
}

output "cb_eks_deploy_qa_role_arn" {
  value = aws_iam_role.cb_eks_deploy_qa.arn
}