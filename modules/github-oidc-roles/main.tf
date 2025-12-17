data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# GitHub OIDC Provider
# This provider enables GitHub Actions to authenticate with AWS using OIDC
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub Actions OIDC thumbprints
  # Updated as of 2024 - these are required for OIDC authentication
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = merge(var.tags, {
    Name = "github-actions-oidc"
  })
}

# ============================================================================
# Terraform Deployment Role
# ============================================================================
# This role allows GitHub Actions to run Terraform operations (plan/apply/destroy)
# for infrastructure management

resource "aws_iam_role" "terraform" {
  name = var.terraform_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              for repo in var.allowed_repos : "repo:${repo}:*"
            ]
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = var.terraform_role_name
    Purpose = "terraform-deployment"
  })
}

# Attach provided managed policies to Terraform role
resource "aws_iam_role_policy_attachment" "terraform_managed" {
  for_each = toset(var.terraform_policy_arns)

  role       = aws_iam_role.terraform.name
  policy_arn = each.value
}

# Default Terraform deployment policy
# Grants permissions for common Terraform operations
resource "aws_iam_policy" "terraform_default" {
  name        = "${var.terraform_role_name}-default-policy"
  description = "Default policy for Terraform deployments via GitHub Actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 backend access for Terraform state
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::*-tfstate-*",
          "arn:${data.aws_partition.current.partition}:s3:::*-tfstate-*/*"
        ]
      },
      # DynamoDB for state locking
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/*-tfstate-lock"
      },
      # Read-only access for planning
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "eks:Describe*",
          "eks:List*",
          "iam:Get*",
          "iam:List*",
          "route53:Get*",
          "route53:List*",
          "ecr:Describe*",
          "ecr:List*",
          "logs:Describe*",
          "logs:List*",
          "secretsmanager:Describe*",
          "secretsmanager:List*",
          "sns:Get*",
          "sns:List*",
          "cloudwatch:Describe*",
          "cloudwatch:List*"
        ]
        Resource = "*"
      },
      # Network resources management
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:CreateSubnet",
          "ec2:CreateInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:CreateRouteTable",
          "ec2:CreateRoute",
          "ec2:CreateSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:ModifyVpcAttribute",
          "ec2:ModifySubnetAttribute",
          "ec2:AllocateAddress",
          "ec2:AssociateRouteTable",
          "ec2:AttachInternetGateway",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DeleteVpc",
          "ec2:DeleteSubnet",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteNatGateway",
          "ec2:DeleteRouteTable",
          "ec2:DeleteRoute",
          "ec2:DeleteSecurityGroup",
          "ec2:ReleaseAddress",
          "ec2:DisassociateRouteTable",
          "ec2:DetachInternetGateway"
        ]
        Resource = "*"
      },
      # IAM role and policy management
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:CreatePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:DeleteRole",
          "iam:DeletePolicy",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:TagOpenIDConnectProvider"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/*",
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:policy/*",
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*"
        ]
      },
      # Route53 DNS management
      {
        Effect = "Allow"
        Action = [
          "route53:CreateHostedZone",
          "route53:DeleteHostedZone",
          "route53:ChangeResourceRecordSets",
          "route53:ChangeTagsForResource"
        ]
        Resource = "*"
      },
      # ACM certificate management
      {
        Effect = "Allow"
        Action = [
          "acm:RequestCertificate",
          "acm:DeleteCertificate",
          "acm:AddTagsToCertificate",
          "acm:RemoveTagsFromCertificate",
          "acm:DescribeCertificate",
          "acm:ListCertificates"
        ]
        Resource = "*"
      },
      # ECR repository management
      {
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:DeleteRepository",
          "ecr:PutLifecyclePolicy",
          "ecr:SetRepositoryPolicy",
          "ecr:TagResource",
          "ecr:UntagResource",
          "ecr:PutReplicationConfiguration",
          "ecr:DeleteReplicationConfiguration"
        ]
        Resource = "*"
      },
      # CloudWatch logs management
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagResource",
          "logs:UntagResource"
        ]
        Resource = "*"
      },
      # Secrets Manager
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:ReplicateSecretToRegions",
          "secretsmanager:RemoveRegionsFromReplication"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.terraform_role_name}-default-policy"
  })
}

resource "aws_iam_role_policy_attachment" "terraform_default" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.terraform_default.arn
}

# ============================================================================
# eksctl Operations Role
# ============================================================================
# This role allows GitHub Actions to run eksctl operations (create/upgrade/delete clusters)

resource "aws_iam_role" "eksctl" {
  name = var.eksctl_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              for repo in var.allowed_repos : "repo:${repo}:*"
            ]
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = var.eksctl_role_name
    Purpose = "eksctl-operations"
  })
}

# Attach provided managed policies to eksctl role
resource "aws_iam_role_policy_attachment" "eksctl_managed" {
  for_each = toset(var.eksctl_policy_arns)

  role       = aws_iam_role.eksctl.name
  policy_arn = each.value
}

# Default eksctl operations policy
# Grants permissions for EKS cluster lifecycle management
resource "aws_iam_policy" "eksctl_default" {
  name        = "${var.eksctl_role_name}-default-policy"
  description = "Default policy for eksctl operations via GitHub Actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EKS cluster management
      {
        Effect = "Allow"
        Action = [
          "eks:*"
        ]
        Resource = "*"
      },
      # EC2 permissions for node groups and networking
      {
        Effect = "Allow"
        Action = [
          "ec2:AllocateAddress",
          "ec2:AssociateRouteTable",
          "ec2:AttachInternetGateway",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:CreateInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:CreateRoute",
          "ec2:CreateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:CreateTags",
          "ec2:CreateVpc",
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteNatGateway",
          "ec2:DeleteRoute",
          "ec2:DeleteRouteTable",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSubnet",
          "ec2:DeleteTags",
          "ec2:DeleteVpc",
          "ec2:DeleteLaunchTemplate",
          "ec2:Describe*",
          "ec2:DetachInternetGateway",
          "ec2:DisassociateRouteTable",
          "ec2:ModifySubnetAttribute",
          "ec2:ModifyVpcAttribute",
          "ec2:ReleaseAddress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      # IAM for node instance profiles and service roles
      {
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:PassRole",
          "iam:CreateServiceLinkedRole",
          "iam:CreateOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
          "iam:GetOpenIDConnectProvider",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:TagOpenIDConnectProvider",
          "iam:TagPolicy"
        ]
        Resource = "*"
      },
      # CloudFormation for eksctl stack management
      {
        Effect = "Allow"
        Action = [
          "cloudformation:*"
        ]
        Resource = "*"
      },
      # AutoScaling for node groups
      {
        Effect = "Allow"
        Action = [
          "autoscaling:*"
        ]
        Resource = "*"
      },
      # CloudWatch Logs for cluster logging
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:DescribeLogGroups",
          "logs:TagResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.eksctl_role_name}-default-policy"
  })
}

resource "aws_iam_role_policy_attachment" "eksctl_default" {
  role       = aws_iam_role.eksctl.name
  policy_arn = aws_iam_policy.eksctl_default.arn
}

# ============================================================================
# ECR Push Role
# ============================================================================
# This role allows GitHub Actions to push container images to ECR

resource "aws_iam_role" "ecr_push" {
  name = var.ecr_push_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              for repo in var.allowed_repos : "repo:${repo}:*"
            ]
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name    = var.ecr_push_role_name
    Purpose = "ecr-image-push"
  })
}

# ECR push policy
resource "aws_iam_policy" "ecr_push" {
  name        = "${var.ecr_push_role_name}-policy"
  description = "Policy for pushing images to ECR via GitHub Actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR login
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      # ECR repository operations
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage"
        ]
        Resource = length(var.ecr_repository_arns) > 0 ? var.ecr_repository_arns : ["*"]
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.ecr_push_role_name}-policy"
  })
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.ecr_push.name
  policy_arn = aws_iam_policy.ecr_push.arn
}
