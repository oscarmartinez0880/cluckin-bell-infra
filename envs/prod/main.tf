terraform {
  required_version = ">= 1.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
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
    Project     = "cluckin-bell"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# DNS and Certificates - Production
module "dns_certs" {
  source = "../../modules/dns-certs"

  public_zone = {
    name   = "cluckn-bell.com"
    create = true
  }

  private_zone = {
    name    = "cluckn-bell.com"
    create  = true
    vpc_id  = module.vpc.vpc_id
    zone_id = null
  }

  # Add NS delegations for dev and qa subdomains from nonprod account
  subdomain_zones = {
    "dev.cluckn-bell.com" = var.dev_zone_name_servers
    "qa.cluckn-bell.com"  = var.qa_zone_name_servers
  }

  certificates = {
    prod_wildcard = {
      domain_name               = "*.cluckn-bell.com"
      subject_alternative_names = ["cluckn-bell.com"]
      use_private_zone          = false
    }
  }

  tags = local.common_tags
}

# VPC
module "vpc" {
  source = "../../modules/vpc"

  name                 = "cluckn-bell-prod"
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  tags = local.common_tags
}

# EKS Cluster
module "eks" {
  source = "../../modules/eks"

  cluster_name       = "cluckn-bell-prod"
  cluster_version    = "1.30"
  subnet_ids         = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
  private_subnet_ids = module.vpc.private_subnet_ids

  tags = local.common_tags
}


# ECR Repository (shared)
module "ecr" {
  source = "../../modules/ecr"

  repository_names = ["cluckin-bell-app"]
  max_image_count  = 10
  tags             = local.common_tags
}

# Monitoring with CloudWatch and Container Insights
module "monitoring" {
  source = "../../modules/monitoring"

  log_groups = {
    "/eks/prod/cluster" = {
      retention_in_days = 7 # Longer retention for prod
    }
    "/eks/prod/apps" = {
      retention_in_days = 7
    }
  }

  container_insights = {
    enabled                   = true
    cluster_name              = "cluckn-bell-prod"
    aws_region                = var.aws_region
    log_retention_days        = 7
    enable_cloudwatch_agent   = true
    enable_fluent_bit         = true
    cloudwatch_agent_role_arn = module.irsa_cloudwatch_agent.role_arn
    fluent_bit_role_arn       = module.irsa_aws_for_fluent_bit.role_arn
  }

  tags = local.common_tags
}

# IRSA Roles
module "irsa_aws_load_balancer_controller" {
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-prod-aws-load-balancer-controller"
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

module "irsa_external_dns" {
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-prod-external-dns"
  oidc_provider_arn = module.eks.oidc_provider_arn
  namespace         = "kube-system"
  service_account   = "external-dns"

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${module.dns_certs.public_zone_id}"
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
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-prod-cluster-autoscaler"
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
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-prod-aws-for-fluent-bit"
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
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/eks/prod/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

module "irsa_cloudwatch_agent" {
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-prod-cloudwatch-agent"
  oidc_provider_arn = module.eks.oidc_provider_arn
  namespace         = "amazon-cloudwatch"
  service_account   = "cloudwatch-agent"

  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

module "irsa_external_secrets" {
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-prod-external-secrets"
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

# Cognito User Pool (no users initially)
module "cognito" {
  source = "../../modules/cognito"

  user_pool_name = "cluckn-bell-prod"
  domain_name    = "cluckn-bell-prod"

  clients = {
    argocd = {
      callback_urls = ["https://argocd.cluckn-bell.com/auth/callback"]
      logout_urls   = ["https://argocd.cluckn-bell.com/"]
    }
    grafana = {
      callback_urls = ["https://grafana.cluckn-bell.com/login/generic_oauth"]
      logout_urls   = ["https://grafana.cluckn-bell.com/"]
    }
  }

  admin_user_emails = [] # No users created in prod initially

  tags = local.common_tags
}

# GitHub OIDC Role for ECR Push
module "github_oidc" {
  source = "../../modules/github-oidc"

  role_name             = "cluckn-bell-prod-github-ecr-push"
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
          module.ecr.repository_arns["cluckin-bell-app"]
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Secrets Manager
module "secrets" {
  source = "../../modules/secrets"

  secrets = {
    "/cluckn-bell/prod/wordpress/prod/database" = {
      description = "WordPress database credentials for prod environment"
      static_values = {
        "host"     = "prod-wordpress-db.cluckn-bell.internal"
        "database" = "wordpress_prod"
        "username" = "wordpress_prod"
      }
      generated_values = {
        "password" = "password"
      }
    }
    "/cluckn-bell/prod/wordpress/prod/auth" = {
      description   = "WordPress auth keys and salts for prod environment"
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
    "/cluckn-bell/prod/mariadb/prod" = {
      description = "MariaDB credentials for prod environment"
      static_values = {
        "host"     = "prod-mariadb.cluckn-bell.internal"
        "database" = "cluckn_bell_prod"
        "username" = "cluckn_bell_prod"
      }
      generated_values = {
        "password"      = "password"
        "root_password" = "root_password"
      }
    }
  }

  tags = local.common_tags
}