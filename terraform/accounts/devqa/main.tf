terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "devqa"
  region = var.region

  # Assume role configuration would go here if needed
  # assume_role {
  #   role_arn = var.devqa_role_arn
  # }

  default_tags {
    tags = merge(var.tags, {
      Account     = "devqa"
      Environment = "devqa"
    })
  }
}

# Get the TLS certificate for GitHub OIDC to derive thumbprints dynamically
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# GitHub OIDC Provider for DevQA account
resource "aws_iam_openid_connect_provider" "github" {
  provider = aws.devqa

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint
  ]

  tags = merge(var.tags, {
    Name = "github-oidc-provider-devqa"
  })
}

# Local values for common trust policy conditions
locals {
  github_oidc_arn = aws_iam_openid_connect_provider.github.arn

  # Common trust policy conditions for GitHub Actions
  github_trust_condition = {
    StringEquals = {
      "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
    }
  }

  # Environment-specific trust conditions
  environment_conditions = {
    dev = {
      StringLike = {
        "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository_owner}/cluckin-bell:environment:dev"
      }
    }
    qa = {
      StringLike = {
        "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository_owner}/cluckin-bell:environment:qa"
      }
    }
  }
}

# EKS Deploy Roles
resource "aws_iam_role" "eks_deploy" {
  provider = aws.devqa
  for_each = toset(var.environments)

  name = "GH_EKS_Deploy_${var.cluster_name_prefix}_${each.value}_use1"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = merge(
          local.github_trust_condition,
          local.environment_conditions[each.value]
        )
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "GH_EKS_Deploy_${var.cluster_name_prefix}_${each.value}_use1"
    Environment = each.value
    Purpose     = "eks-deploy"
  })
}

# EKS Deploy Policy
resource "aws_iam_policy" "eks_deploy" {
  provider = aws.devqa
  for_each = toset(var.environments)

  name        = "GH_EKS_Deploy_${var.cluster_name_prefix}_${each.value}_use1_policy"
  description = "Policy for GitHub Actions to deploy to EKS cluster ${each.value}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:DescribeNodegroup",
          "eks:DescribeFargateProfile",
          "eks:DescribeUpdate",
          "eks:ListNodegroups",
          "eks:ListFargateProfiles",
          "eks:ListUpdates",
          "eks:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "GH_EKS_Deploy_${var.cluster_name_prefix}_${each.value}_use1_policy"
    Environment = each.value
    Purpose     = "eks-deploy"
  })
}

# Attach EKS Deploy Policy to Role
resource "aws_iam_role_policy_attachment" "eks_deploy" {
  provider = aws.devqa
  for_each = toset(var.environments)

  role       = aws_iam_role.eks_deploy[each.value].name
  policy_arn = aws_iam_policy.eks_deploy[each.value].arn
}

# ECR Push Roles - one per repository and environment combination
resource "aws_iam_role" "ecr_push" {
  provider = aws.devqa
  for_each = {
    for combo in setproduct(var.app_repositories, var.environments) :
    "${combo[0]}_${combo[1]}" => {
      repository  = combo[0]
      environment = combo[1]
    }
  }

  name = "GH_ECR_Push_${replace(each.value.repository, "-", "_")}_${each.value.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = merge(
          local.github_trust_condition,
          {
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository_owner}/${each.value.repository}:environment:${each.value.environment}"
            }
          }
        )
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "GH_ECR_Push_${replace(each.value.repository, "-", "_")}_${each.value.environment}"
    Repository  = each.value.repository
    Environment = each.value.environment
    Purpose     = "ecr-push"
  })
}

# ECR Push Policy - scoped to specific repository
resource "aws_iam_policy" "ecr_push" {
  provider = aws.devqa
  for_each = {
    for combo in setproduct(var.app_repositories, var.environments) :
    "${combo[0]}_${combo[1]}" => {
      repository  = combo[0]
      environment = combo[1]
    }
  }

  name        = "GH_ECR_Push_${replace(each.value.repository, "-", "_")}_${each.value.environment}_policy"
  description = "Policy for GitHub Actions to push to ECR repository ${each.value.repository} in ${each.value.environment}"

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
          "ecr:DescribeRepositories",
          "ecr:DescribeImages",
          "ecr:ListImages",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          aws_ecr_repository.repositories[each.value.repository].arn
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "GH_ECR_Push_${replace(each.value.repository, "-", "_")}_${each.value.environment}_policy"
    Repository  = each.value.repository
    Environment = each.value.environment
    Purpose     = "ecr-push"
  })
}

# Attach ECR Push Policy to Role
resource "aws_iam_role_policy_attachment" "ecr_push" {
  provider = aws.devqa
  for_each = {
    for combo in setproduct(var.app_repositories, var.environments) :
    "${combo[0]}_${combo[1]}" => {
      repository  = combo[0]
      environment = combo[1]
    }
  }

  role       = aws_iam_role.ecr_push[each.key].name
  policy_arn = aws_iam_policy.ecr_push[each.key].arn
}

# ECR Repositories
resource "aws_ecr_repository" "repositories" {
  provider = aws.devqa
  for_each = toset(var.app_repositories)

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name       = each.value
    Repository = each.value
  })
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "repositories" {
  provider   = aws.devqa
  for_each   = toset(var.app_repositories)
  repository = aws_ecr_repository.repositories[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.ecr_lifecycle_keep_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "main", "develop"]
          countType     = "imageCountMoreThan"
          countNumber   = var.ecr_lifecycle_keep_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# CodeCommit Mirroring Role for GitHub Actions
resource "aws_iam_role" "codecommit_mirror" {
  provider = aws.devqa
  name     = "GH_CodeCommit_Mirror"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = merge(
          local.github_trust_condition,
          {
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository_owner}/cluckin-bell:ref:refs/heads/main"
            }
          }
        )
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "GH_CodeCommit_Mirror"
    Purpose = "github-codecommit-mirroring"
  })
}

# CodeCommit Mirroring Policy
resource "aws_iam_policy" "codecommit_mirror" {
  provider = aws.devqa
  name     = "GH_CodeCommit_Mirror_Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPush"
        ]
        Resource = "arn:aws:codecommit:us-east-1:${data.aws_caller_identity.current.account_id}:cluckin-bell"
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = "GH_CodeCommit_Mirror_Policy"
    Purpose = "github-codecommit-mirroring"
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "codecommit_mirror" {
  provider   = aws.devqa
  role       = aws_iam_role.codecommit_mirror.name
  policy_arn = aws_iam_policy.codecommit_mirror.arn
}

# Data source for current account ID
data "aws_caller_identity" "current" {
  provider = aws.devqa
}

# ECR Read Role for cluckin-bell-app
resource "aws_iam_role" "ecr_read_cluckin_bell_app" {
  provider = aws.devqa
  name     = "GH_ECR_Read_cluckin_bell_app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = merge(
          local.github_trust_condition,
          {
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository_owner}/cluckin-bell:environment:qa"
            }
          }
        )
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "GH_ECR_Read_cluckin_bell_app"
    Environment = "qa"
    Purpose     = "ecr-read"
  })
}

# ECR Read Policy for cluckin-bell-app
resource "aws_iam_policy" "ecr_read_cluckin_bell_app" {
  provider = aws.devqa
  name     = "GH_ECR_Read_cluckin_bell_app_policy"
  description = "Policy for GitHub Actions to read ECR tags for cluckin-bell-app repository"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:DescribeRepositories",
          "ecr:ListImages", 
          "ecr:DescribeImages",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:${var.region}:${var.account_id}:repository/cluckin-bell-app"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "GH_ECR_Read_cluckin_bell_app_policy"
    Environment = "qa"
    Purpose     = "ecr-read"
  })
}

# Attach ECR Read Policy to Role
resource "aws_iam_role_policy_attachment" "ecr_read_cluckin_bell_app" {
  provider   = aws.devqa
  role       = aws_iam_role.ecr_read_cluckin_bell_app.name
  policy_arn = aws_iam_policy.ecr_read_cluckin_bell_app.arn
}

# SES Send Role for QA environment
resource "aws_iam_role" "ses_send_cluckin_bell_qa" {
  provider = aws.devqa
  name     = "GH_SES_Send_cluckin_bell_qa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = merge(
          local.github_trust_condition,
          {
            StringLike = {
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository_owner}/cluckin-bell:environment:qa"
            }
          }
        )
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "GH_SES_Send_cluckin_bell_qa"
    Environment = "qa"
    Purpose     = "ses-send"
  })
}

# SES Send Policy for QA environment
resource "aws_iam_policy" "ses_send_cluckin_bell_qa" {
  provider = aws.devqa
  name     = "GH_SES_Send_cluckin_bell_qa_policy"
  description = "Policy for GitHub Actions to send emails via SES in QA environment"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.region
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "GH_SES_Send_cluckin_bell_qa_policy"
    Environment = "qa"
    Purpose     = "ses-send"
  })
}

# Attach SES Send Policy to Role
resource "aws_iam_role_policy_attachment" "ses_send_cluckin_bell_qa" {
  provider   = aws.devqa
  role       = aws_iam_role.ses_send_cluckin_bell_qa.name
  policy_arn = aws_iam_policy.ses_send_cluckin_bell_qa.arn
}

# Optional GitHub workflow management
module "github_workflow" {
  count  = var.manage_github_workflow ? 1 : 0
  source = "../../../modules/github-workflow"

  manage_github_workflow     = var.manage_github_workflow
  repository_name            = var.github_repository_name
  codecommit_mirror_role_arn = aws_iam_role.codecommit_mirror.arn

  depends_on = [aws_iam_role.codecommit_mirror]
}