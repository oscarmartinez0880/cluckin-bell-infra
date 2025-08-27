# IAM + CodeCommit for GitHub Actions mirroring. Reuses the existing OIDC provider data source
# defined in iam/github-actions-ecr.tf as data.aws_iam_openid_connect_provider.github.

resource "aws_codecommit_repository" "app" {
  repository_name = var.codecommit_repo_name
  description     = "Mirror target for ${var.codecommit_repo_name} (${var.environment})"
  tags = {
    Project     = "cluckin-bell"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "mirror_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:oscarmartinez0880/cluckn-bell:*"]
    }
  }
}

resource "aws_iam_role" "github_mirror" {
  name               = "cb-${var.environment}-github-codecommit-mirror"
  assume_role_policy = data.aws_iam_policy_document.mirror_assume_role.json
  tags = {
    Project     = "cluckin-bell"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "mirror_policy" {
  statement {
    sid    = "CodeCommitPush"
    effect = "Allow"
    actions = [
      "codecommit:GitPush",
      "codecommit:GitPull",
      "codecommit:ListBranches",
      "codecommit:ListRepositories",
      "codecommit:BatchGet*",
      "codecommit:Get*"
    ]
    resources = [aws_codecommit_repository.app.arn]
  }
}

resource "aws_iam_policy" "mirror" {
  name   = "cb-${var.environment}-github-codecommit-mirror"
  policy = data.aws_iam_policy_document.mirror_policy.json
}

resource "aws_iam_role_policy_attachment" "mirror_attach" {
  role       = aws_iam_role.github_mirror.name
  policy_arn = aws_iam_policy.mirror.arn
}