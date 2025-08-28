terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IRSA IAM Role
resource "aws_iam_role" "irsa" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account}"
            "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Attach managed policies
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.irsa.name
  policy_arn = each.value
}

# Create and attach custom policy if provided
resource "aws_iam_policy" "custom" {
  count = var.custom_policy_json != null ? 1 : 0

  name   = "${var.role_name}-policy"
  policy = var.custom_policy_json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "custom" {
  count = var.custom_policy_json != null ? 1 : 0

  role       = aws_iam_role.irsa.name
  policy_arn = aws_iam_policy.custom[0].arn
}