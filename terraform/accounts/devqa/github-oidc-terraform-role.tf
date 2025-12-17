# IAM role for Terraform deploys from GitHub Actions (Dev/QA account 264765154707)
# Trusts the oscarmartinez0880/cluckin-bell-infra repo for environments dev and qa

data "aws_iam_policy_document" "tf_deploy_trust_devqa" {
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

    # Restrict to this repo + GitHub Environments dev, qa, and nonprod
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repository_owner}/cluckin-bell-infra:environment:dev",
        "repo:${var.github_repository_owner}/cluckin-bell-infra:environment:qa",
        "repo:${var.github_repository_owner}/cluckin-bell-infra:environment:nonprod",
      ]
    }
  }
}

resource "aws_iam_role" "tf_deploy_devqa" {
  provider           = aws.devqa
  name               = "cb-terraform-deploy-devqa"
  assume_role_policy = data.aws_iam_policy_document.tf_deploy_trust_devqa.json

  tags = merge(var.tags, {
    Name        = "cb-terraform-deploy-devqa"
    Environment = "devqa"
    Purpose     = "terraform-deploy"
  })
}

# Bootstrap with admin; tighten later to least-privilege policies for your TF scope
resource "aws_iam_role_policy_attachment" "tf_deploy_devqa_admin" {
  provider   = aws.devqa
  role       = aws_iam_role.tf_deploy_devqa.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}