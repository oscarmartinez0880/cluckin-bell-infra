terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend configuration will be provided via terraform init -backend-config
  # or via a backend.hcl file
  # Example backend.hcl:
  # bucket         = "your-terraform-state-bucket"
  # key            = "terraform.tfstate"
  # region         = "us-east-1"
  # dynamodb_table = "terraform-state-lock"
  # encrypt        = true
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.default_tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name                 = var.name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpc_endpoints = var.enable_vpc_endpoints

  tags = local.common_tags
}

# IAM Module
module "iam" {
  source = "./modules/iam"

  name_prefix        = var.name
  enable_github_oidc = var.enable_github_oidc

  tags = local.common_tags
}

# IRSA roles - separate module call for EKS-specific IAM roles
module "iam_irsa" {
  count  = var.enable_eks ? 1 : 0
  source = "./modules/iam"

  name_prefix = "${var.name}-irsa"
  irsa_roles  = local.irsa_roles_config

  tags = local.common_tags

  depends_on = [module.eks]
}

# EKS Module
module "eks" {
  count  = var.enable_eks ? 1 : 0
  source = "./modules/eks"

  cluster_name            = "${var.name}-eks"
  kubernetes_version      = var.kubernetes_version
  subnet_ids              = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  private_subnet_ids      = module.vpc.private_subnet_ids
  endpoint_private_access = var.eks_endpoint_private_access
  endpoint_public_access  = var.eks_endpoint_public_access
  public_access_cidrs     = var.eks_public_access_cidrs
  cluster_log_types       = var.eks_cluster_log_types

  # Node group configuration
  capacity_type  = var.eks_capacity_type
  instance_types = var.eks_instance_types
  desired_size   = var.eks_desired_size
  max_size       = var.eks_max_size
  min_size       = var.eks_min_size

  # GitHub Actions integration
  enable_github_actions_role = var.enable_github_actions_role
  github_oidc_provider_arn   = module.iam.github_oidc_provider_arn
  github_repo                = var.github_repo

  tags = local.common_tags
}

# ECR Module
module "ecr" {
  count  = var.enable_ecr ? 1 : 0
  source = "./modules/ecr"

  repository_names        = var.ecr_repository_names
  image_tag_mutability    = var.ecr_image_tag_mutability
  scan_on_push            = var.ecr_scan_on_push
  enable_lifecycle_policy = var.ecr_enable_lifecycle_policy
  max_image_count         = var.ecr_max_image_count

  tags = local.common_tags
}

# RDS Module
module "rds" {
  count  = var.enable_rds ? 1 : 0
  source = "./modules/rds"

  identifier            = "${var.name}-db"
  engine                = var.rds_engine
  engine_version        = var.rds_engine_version
  instance_class        = var.rds_instance_class
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage

  db_name  = var.rds_db_name
  username = var.rds_username
  port     = var.rds_port

  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_groups = var.enable_eks ? [module.eks[0].cluster_security_group_id] : []

  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = var.rds_deletion_protection

  tags = local.common_tags
}

# ElastiCache Module
module "elasticache" {
  count  = var.enable_elasticache ? 1 : 0
  source = "./modules/elasticache"

  cluster_id         = "${var.name}-cache"
  engine             = var.elasticache_engine
  engine_version     = var.elasticache_engine_version
  node_type          = var.elasticache_node_type
  num_cache_clusters = var.elasticache_num_cache_clusters

  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_groups = var.enable_eks ? [module.eks[0].cluster_security_group_id] : []

  tags = local.common_tags
}

# EFS Module
module "efs" {
  count  = var.enable_efs ? 1 : 0
  source = "./modules/efs"

  name                    = "${var.name}-efs"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_groups = var.enable_eks ? [module.eks[0].cluster_security_group_id] : []

  access_points = var.efs_access_points

  tags = local.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  # Basic monitoring setup
  log_groups = {
    "/aws/lambda/${var.name}" = {
      retention_in_days = 14
    }
    "/aws/apigateway/${var.name}" = {
      retention_in_days = 7
    }
  }

  # SNS topics for alerts
  sns_topics = var.enable_monitoring ? {
    alerts = {
      display_name = "${var.name} Alerts"
      subscriptions = var.monitoring_email_endpoints != null ? [
        for email in var.monitoring_email_endpoints : {
          protocol = "email"
          endpoint = email
        }
      ] : []
    }
  } : {}

  # Basic alarms
  metric_alarms = var.enable_monitoring && var.enable_eks ? {
    eks-cluster-failed-requests = {
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "cluster-autoscaler.failed-requests"
      namespace           = "AWS/EKS"
      period              = 300
      statistic           = "Sum"
      threshold           = 5
      alarm_description   = "EKS cluster has failed requests"
      alarm_actions       = [module.monitoring.sns_topic_arns["alerts"]]
      dimensions = {
        ClusterName = module.eks[0].cluster_name
      }
    }
  } : {}

  tags = local.common_tags
}

# Local values
locals {
  common_tags = merge(var.default_tags, {
    Environment = var.environment
    Project     = var.name
    ManagedBy   = "Terraform"
  })

  # IRSA roles configuration
  irsa_roles_config = {
    cluster_autoscaler = {
      oidc_provider_arn = module.eks[0].oidc_provider_arn
      namespace         = "kube-system"
      service_account   = "cluster-autoscaler"
      policy_arns = [
        "arn:aws:iam::aws:policy/AutoScalingFullAccess"
      ]
    }
    aws_load_balancer_controller = {
      oidc_provider_arn = module.eks[0].oidc_provider_arn
      namespace         = "kube-system"
      service_account   = "aws-load-balancer-controller"
      custom_policies = {
        alb_controller = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect = "Allow"
              Action = [
                "iam:CreateServiceLinkedRole",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAddresses",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeInstances",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeTags",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeCoipPools",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerCertificates",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTags"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "waf-regional:GetWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:AssociateWebACL",
                "waf-regional:DisassociateWebACL",
                "wafv2:GetWebACL",
                "wafv2:GetWebACLForResource",
                "wafv2:AssociateWebACL",
                "wafv2:DisassociateWebACL",
                "shield:DescribeProtection",
                "shield:GetSubscriptionState",
                "shield:DescribeSubscription",
                "shield:CreateProtection",
                "shield:DeleteProtection"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "ec2:CreateSecurityGroup"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "ec2:CreateTags"
              ]
              Resource = "arn:aws:ec2:*:*:security-group/*"
              Condition = {
                StringEquals = {
                  "ec2:CreateAction" = "CreateSecurityGroup"
                }
                Null = {
                  "aws:RequestedRegion" = "false"
                }
              }
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateTargetGroup"
              ]
              Resource = "*"
              Condition = {
                Null = {
                  "aws:RequestedRegion" = "false"
                }
              }
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:DeleteRule"
              ]
              Resource = "*"
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
              ]
              Resource = [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
              ]
              Condition = {
                Null = {
                  "aws:RequestedRegion"                   = "false"
                  "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
                }
              }
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:RemoveTags"
              ]
              Resource = [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
              ]
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:DeleteTargetGroup"
              ]
              Resource = "*"
              Condition = {
                Null = {
                  "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
                }
              }
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
              ]
              Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
            },
            {
              Effect = "Allow"
              Action = [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule"
              ]
              Resource = "*"
            }
          ]
        })
      }
    }
  }
}