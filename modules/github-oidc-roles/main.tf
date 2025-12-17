data "aws_caller_identity" "current" {}

# GitHub OIDC Provider
# Creates the provider if it doesn't already exist
# If it already exists, Terraform will show an error on apply and you should import it
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub OIDC thumbprints (current as of 2024)
  # These are the SHA-1 fingerprints of the root and intermediate CA certificates
  thumbprint_list = [
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd", # Current root CA thumbprint
    "a031c46782e6e6c662c2c87c76da9aa62ccabd8e"  # Intermediate CA thumbprint
  ]

  tags = var.tags

  lifecycle {
    # Prevent accidental deletion of OIDC provider
    prevent_destroy = true
  }
}

locals {
  github_oidc_provider_arn = aws_iam_openid_connect_provider.github.arn

  # Common trust policy for all roles
  trust_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = var.allowed_repos
          }
        }
      }
    ]
  }
}

# IAM Role for Terraform
resource "aws_iam_role" "terraform" {
  name               = var.terraform_role_name
  assume_role_policy = jsonencode(local.trust_policy)
  tags               = var.tags
}

# Attach managed policies to Terraform role
resource "aws_iam_role_policy_attachment" "terraform" {
  for_each = toset(var.terraform_policy_arns)

  role       = aws_iam_role.terraform.name
  policy_arn = each.value
}

# IAM Role for eksctl
resource "aws_iam_role" "eksctl" {
  name               = var.eksctl_role_name
  assume_role_policy = jsonencode(local.trust_policy)
  tags               = var.tags
}

# Attach managed policies to eksctl role
resource "aws_iam_role_policy_attachment" "eksctl" {
  for_each = toset(var.eksctl_policy_arns)

  role       = aws_iam_role.eksctl.name
  policy_arn = each.value
}

# IAM Role for ECR Push
resource "aws_iam_role" "ecr_push" {
  name               = var.ecr_push_role_name
  assume_role_policy = jsonencode(local.trust_policy)
  tags               = var.tags
}

# Attach managed policies to ECR Push role
resource "aws_iam_role_policy_attachment" "ecr_push" {
  for_each = toset(var.ecr_push_policy_arns)

  role       = aws_iam_role.ecr_push.name
  policy_arn = each.value
}
