terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "cluckin-bell"
      Stack       = "bootstrap"
      ManagedBy   = "terraform"
    }
  }
}

# GitHub OIDC Provider
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = length(data.aws_iam_openid_connect_provider.github.arn) == 0 ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "github-oidc-provider"
  }
}

locals {
  github_oidc_arn = length(data.aws_iam_openid_connect_provider.github.arn) > 0 ? data.aws_iam_openid_connect_provider.github.arn : aws_iam_openid_connect_provider.github[0].arn
}

# IAM Role for GitHub Actions ECR Push
resource "aws_iam_role" "gha_ecr_push" {
  name = "gha-ecr-push"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:oscarmartinez0880/cluckin-bell-app:*",
              "repo:oscarmartinez0880/cluckin-bell-infra:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "gha-ecr-push"
  }
}

# IAM Policy for ECR Push
resource "aws_iam_policy" "gha_ecr_push" {
  name        = "gha-ecr-push-policy"
  description = "Policy for GitHub Actions to push images to ECR repositories under cluckin-bell/*"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:*:*:repository/cluckin-bell/*"
      }
    ]
  })

  tags = {
    Name = "gha-ecr-push-policy"
  }
}

# Attach ECR policy to ECR push role
resource "aws_iam_role_policy_attachment" "gha_ecr_push" {
  role       = aws_iam_role.gha_ecr_push.name
  policy_arn = aws_iam_policy.gha_ecr_push.arn
}

# IAM Role for GitHub Actions EKS Deploy
resource "aws_iam_role" "gha_eks_deploy" {
  name = "gha-eks-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:oscarmartinez0880/cluckin-bell-app:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "gha-eks-deploy"
  }
}

# IAM Policy for EKS Deploy
resource "aws_iam_policy" "gha_eks_deploy" {
  name        = "gha-eks-deploy-policy"
  description = "Policy for GitHub Actions to authenticate to EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "gha-eks-deploy-policy"
  }
}

# Attach EKS policy to EKS deploy role
resource "aws_iam_role_policy_attachment" "gha_eks_deploy" {
  role       = aws_iam_role.gha_eks_deploy.name
  policy_arn = aws_iam_policy.gha_eks_deploy.arn
}