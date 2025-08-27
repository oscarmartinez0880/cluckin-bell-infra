# GitHub OIDC provider reference
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Role to allow GitHub Actions from oscarmartinez0880/cluckin-bell-app to push to ECR
resource "aws_iam_role" "github_actions_ecr_push" {
  name = "${var.environment}-cb-github-actions-ecr-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        StringLike = {
          "token.actions.githubusercontent.com:sub": "repo:oscarmartinez0880/cluckin-bell-app:*"
        }
      }
    }]
  })

  tags = {
    Environment = var.environment
    Project     = "cluckin-bell"
    Stack       = "registry-obsv"
  }
}

# Least-privilege policy for ECR push
data "aws_iam_policy_document" "ecr_push" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories",
      "ecr:ListImages"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_push" {
  name   = "${var.environment}-cb-github-actions-ecr-push"
  policy = data.aws_iam_policy_document.ecr_push.json
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.github_actions_ecr_push.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

output "github_actions_ecr_push_role_arn" {
  description = "IAM role ARN for GitHub Actions to push images to ECR"
  value       = aws_iam_role.github_actions_ecr_push.arn
}