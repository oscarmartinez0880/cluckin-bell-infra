terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  common_tags = {
    Application = "cluckn-bell"
    Environment = "nonprod"
    Owner       = "oscarmartinez0880"
    ManagedBy   = "terraform"
  }
}

# VPC
module "vpc" {
  source = "../../modules_new/vpc"

  name                 = "cluckn-bell-nonprod"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "../../modules_new/eks"

  cluster_name       = "cluckn-bell-nonprod"
  kubernetes_version = "1.29"
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  node_groups = {
    ng-dev = {
      instance_type = "t3.small"
      desired_size  = 1
      min_size      = 1
      max_size      = 2
      labels = {
        env = "dev"
      }
    }
    ng-qa = {
      instance_type = "t3.small"
      desired_size  = 1
      min_size      = 1
      max_size      = 2
      labels = {
        env = "qa"
      }
    }
  }

  tags = local.common_tags
}

# Route53 Hosted Zones
module "dev_zone" {
  source = "../../modules_new/route53_zone"

  zone_name = "dev.cluckn-bell.com"
  tags      = local.common_tags
}

module "qa_zone" {
  source = "../../modules_new/route53_zone"

  zone_name = "qa.cluckn-bell.com"
  tags      = local.common_tags
}

# ACM Certificates
module "dev_cert" {
  source = "../../modules_new/acm"

  domain_name = "*.dev.cluckn-bell.com"
  zone_id     = module.dev_zone.zone_id
  tags        = local.common_tags
}

module "qa_cert" {
  source = "../../modules_new/acm"

  domain_name = "*.qa.cluckn-bell.com"
  zone_id     = module.qa_zone.zone_id
  tags        = local.common_tags
}

# ECR Repository
module "ecr" {
  source = "../../modules_new/ecr"

  repository_name = "cluckin-bell-app"
  max_image_count = 10
  tags            = local.common_tags
}

# CloudWatch Log Groups
module "cloudwatch" {
  source = "../../modules_new/cloudwatch"

  log_groups = {
    "/eks/nonprod/cluster" = "EKS cluster logs"
    "/eks/nonprod/apps"    = "Application logs"
  }
  retention_in_days = 1
  tags              = local.common_tags
}

# IRSA Roles
module "irsa_aws_load_balancer_controller" {
  source = "../../modules_new/irsa"

  role_name         = "cluckn-bell-nonprod-aws-load-balancer-controller"
  oidc_provider_arn = module.eks.oidc_provider_arn
  namespace         = "kube-system"
  service_account   = "aws-load-balancer-controller"

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  ]

  custom_policy_json = jsonencode({
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
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
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
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
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
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
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

  tags = local.common_tags
}

module "irsa_external_dns_dev" {
  source = "../../modules_new/irsa"

  role_name         = "cluckn-bell-nonprod-external-dns-dev"
  oidc_provider_arn = module.eks.oidc_provider_arn
  namespace         = "kube-system"
  service_account   = "external-dns-dev"

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${module.dev_zone.zone_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = local.common_tags
}

module "irsa_external_dns_qa" {
  source = "../../modules_new/irsa"

  role_name         = "cluckn-bell-nonprod-external-dns-qa"
  oidc_provider_arn = module.eks.oidc_provider_arn
  namespace         = "kube-system"
  service_account   = "external-dns-qa"

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${module.qa_zone.zone_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = ["*"]
      }
    ]
  })

  tags = local.common_tags
}

module "irsa_cluster_autoscaler" {
  source = "../../modules_new/irsa"

  role_name         = "cluckn-bell-nonprod-cluster-autoscaler"
  oidc_provider_arn = module.eks.oidc_provider_arn
  namespace         = "kube-system"
  service_account   = "cluster-autoscaler"

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

module "irsa_aws_for_fluent_bit" {
  source = "../../modules_new/irsa"

  role_name         = "cluckn-bell-nonprod-aws-for-fluent-bit"
  oidc_provider_arn = module.eks.oidc_provider_arn
  namespace         = "amazon-cloudwatch"
  service_account   = "fluent-bit"

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/eks/nonprod/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

module "irsa_external_secrets" {
  source = "../../modules_new/irsa"

  role_name         = "cluckn-bell-nonprod-external-secrets"
  oidc_provider_arn = module.eks.oidc_provider_arn
  namespace         = "external-secrets-system"
  service_account   = "external-secrets"

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:/cluckn-bell/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Cognito User Pool
module "cognito" {
  source = "../../modules_new/cognito"

  user_pool_name = "cluckn-bell-nonprod"
  domain_name    = "cluckn-bell-nonprod"

  clients = {
    argocd = {
      callback_urls = ["https://argocd.dev.cluckn-bell.com/auth/callback", "https://argocd.qa.cluckn-bell.com/auth/callback"]
      logout_urls   = ["https://argocd.dev.cluckn-bell.com/", "https://argocd.qa.cluckn-bell.com/"]
    }
    grafana = {
      callback_urls = ["https://grafana.dev.cluckn-bell.com/login/generic_oauth", "https://grafana.qa.cluckn-bell.com/login/generic_oauth"]
      logout_urls   = ["https://grafana.dev.cluckn-bell.com/", "https://grafana.qa.cluckn-bell.com/"]
    }
  }

  admin_user_emails = [
    "oscarm21@cluckn-bell.com",
    "rachaelm17@cluckn-bell.com",
    "rudyr99@cluckn-bell.com"
  ]

  tags = local.common_tags
}

# GitHub OIDC Role for ECR Push
module "github_oidc" {
  source = "../../modules_new/github_oidc"

  role_name             = "cluckn-bell-nonprod-github-ecr-push"
  github_repo_condition = "repo:oscarmartinez0880/cluckin-bell-app:ref:refs/heads/develop"

  custom_policy_json = jsonencode({
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
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          module.ecr.repository_arn
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Secrets Manager
module "secrets" {
  source = "../../modules_new/secrets"

  secrets = {
    "/cluckn-bell/nonprod/wordpress/dev/database" = {
      description = "WordPress database credentials for dev environment"
      static_values = {
        "host"     = "dev-wordpress-db.cluckn-bell.internal"
        "database" = "wordpress_dev"
        "username" = "wordpress_dev"
      }
      generated_values = {
        "password" = "password"
      }
    }
    "/cluckn-bell/nonprod/wordpress/dev/auth" = {
      description   = "WordPress auth keys and salts for dev environment"
      static_values = {}
      generated_values = {
        "AUTH_KEY"         = "auth_key"
        "SECURE_AUTH_KEY"  = "secure_auth_key"
        "LOGGED_IN_KEY"    = "logged_in_key"
        "NONCE_KEY"        = "nonce_key"
        "AUTH_SALT"        = "auth_salt"
        "SECURE_AUTH_SALT" = "secure_auth_salt"
        "LOGGED_IN_SALT"   = "logged_in_salt"
        "NONCE_SALT"       = "nonce_salt"
      }
    }
    "/cluckn-bell/nonprod/mariadb/dev" = {
      description = "MariaDB credentials for dev environment"
      static_values = {
        "host"     = "dev-mariadb.cluckn-bell.internal"
        "database" = "cluckn_bell_dev"
        "username" = "cluckn_bell_dev"
      }
      generated_values = {
        "password"      = "password"
        "root_password" = "root_password"
      }
    }
    "/cluckn-bell/nonprod/wordpress/qa/database" = {
      description = "WordPress database credentials for qa environment"
      static_values = {
        "host"     = "qa-wordpress-db.cluckn-bell.internal"
        "database" = "wordpress_qa"
        "username" = "wordpress_qa"
      }
      generated_values = {
        "password" = "password"
      }
    }
    "/cluckn-bell/nonprod/wordpress/qa/auth" = {
      description   = "WordPress auth keys and salts for qa environment"
      static_values = {}
      generated_values = {
        "AUTH_KEY"         = "auth_key"
        "SECURE_AUTH_KEY"  = "secure_auth_key"
        "LOGGED_IN_KEY"    = "logged_in_key"
        "NONCE_KEY"        = "nonce_key"
        "AUTH_SALT"        = "auth_salt"
        "SECURE_AUTH_SALT" = "secure_auth_salt"
        "LOGGED_IN_SALT"   = "logged_in_salt"
        "NONCE_SALT"       = "nonce_salt"
      }
    }
    "/cluckn-bell/nonprod/mariadb/qa" = {
      description = "MariaDB credentials for qa environment"
      static_values = {
        "host"     = "qa-mariadb.cluckn-bell.internal"
        "database" = "cluckn_bell_qa"
        "username" = "cluckn_bell_qa"
      }
      generated_values = {
        "password"      = "password"
        "root_password" = "root_password"
      }
    }
  }

  tags = local.common_tags
}