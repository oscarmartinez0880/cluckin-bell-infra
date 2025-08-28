# IAM role for Terraform deploys from GitHub Actions (Prod account 346746763840)
# Trusts the oscarmartinez0880/cluckin-bell-infra repo for environment prod

data "aws_iam_policy_document" "tf_deploy_trust_prod" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = ["repo:${var.github_repository_owner}/cluckin-bell-infra:environment:prod"]
    }
  }
}

resource "aws_iam_role" "tf_deploy_prod" {
  provider           = aws.prod
  name               = "cb-terraform-deploy-prod"
  assume_role_policy = data.aws_iam_policy_document.tf_deploy_trust_prod.json

  tags = merge(var.tags, {
    Name        = "cb-terraform-deploy-prod"
    Environment = "prod"
    Purpose     = "terraform-deploy"
  })
}

resource "aws_iam_role_policy_attachment" "tf_deploy_prod_admin" {
  provider   = aws.prod
  role       = aws_iam_role.tf_deploy_prod.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}