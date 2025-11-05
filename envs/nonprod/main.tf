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

  backend "s3" {
    bucket = "cluckn-bell-tfstate-nonprod"
    key    = "nonprod/terraform.tfstate"
    region = "us-east-1"
  }
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
    Environment = "nonprod"
    ManagedBy   = "terraform"
  }
}

# DNS and Certificates - Dev subdomain in QA account
# Enabled by default (var.enable_dns = true) as Route53 hosted zone costs are acceptable
module "dns_certs_dev" {
  count  = var.enable_dns ? 1 : 0
  source = "../../modules/dns-certs"

  # Use existing public zone dev.cluckn-bell.com in QA
  public_zone = {
    name   = "dev.cluckn-bell.com"
    create = false
  }

  # Do not create private zone to avoid additional hosted zone costs
  # Reuse existing zones where possible
  private_zone = {
    name    = "cluckn-bell.com"
    create  = false
    vpc_id  = local.vpc_id
    zone_id = null
  }

  certificates = {
    dev_wildcard = {
      domain_name               = "*.dev.cluckn-bell.com"
      subject_alternative_names = ["dev.cluckn-bell.com"]
      use_private_zone          = false
    }
  }

  tags = local.common_tags
}

# DNS and Certificates - QA subdomain in QA account
# Enabled by default (var.enable_dns = true) as Route53 hosted zone costs are acceptable
module "dns_certs_qa" {
  count  = var.enable_dns ? 1 : 0
  source = "../../modules/dns-certs"

  # Use existing public zone qa.cluckn-bell.com in QA
  public_zone = {
    name   = "qa.cluckn-bell.com"
    create = false
  }

  # Do not create private zone to avoid additional hosted zone costs
  private_zone = {
    name    = "cluckn-bell.com"
    create  = false
    vpc_id  = local.vpc_id
    zone_id = null
  }

  certificates = {
    qa_wildcard = {
      domain_name               = "*.qa.cluckn-bell.com"
      subject_alternative_names = ["qa.cluckn-bell.com"]
      use_private_zone          = false
    }
  }

  tags = local.common_tags

  depends_on = [module.dns_certs_dev]
}

# ECR Repository
# Disabled by default (var.enable_ecr = false) to prevent costs from image storage
module "ecr" {
  count  = var.enable_ecr ? 1 : 0
  source = "../../modules/ecr"

  repository_names = ["cluckin-bell-app"]
  max_image_count  = 10
  tags             = local.common_tags
}

# Monitoring with CloudWatch and Container Insights
# Disabled by default (var.enable_monitoring = false) to prevent monitoring costs
# NOTE: When enabled, also enable var.enable_irsa=true for agent IRSA roles
module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "../../modules/monitoring"

  log_groups = {
    "/eks/nonprod/cluster" = {
      retention_in_days = 1
    }
    "/eks/nonprod/apps" = {
      retention_in_days = 1
    }
  }

  # Container Insights disabled by default as safety measure
  # Even when module is enabled, agents should be explicitly turned on
  container_insights = {
    enabled                   = false
    cluster_name              = "cluckn-bell-nonprod"
    aws_region                = var.aws_region
    log_retention_days        = 1
    enable_cloudwatch_agent   = false
    enable_fluent_bit         = false
    cloudwatch_agent_role_arn = var.enable_irsa ? module.irsa_cloudwatch_agent[0].role_arn : ""
    fluent_bit_role_arn       = var.enable_irsa ? module.irsa_aws_for_fluent_bit[0].role_arn : ""
  }

  tags = local.common_tags
}

# IRSA Roles
# All IRSA roles disabled by default (var.enable_irsa = false)
# These require an EKS cluster with OIDC provider to exist
# Enable with var.enable_irsa=true when EKS cluster is provisioned
module "irsa_aws_load_balancer_controller" {
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-nonprod-aws-load-balancer-controller"
  oidc_provider_arn = local.cluster_oidc_provider_arn
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
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-nonprod-external-dns-dev"
  oidc_provider_arn = local.cluster_oidc_provider_arn
  namespace         = "kube-system"
  service_account   = "external-dns-dev"

  # Note: Variable validation ensures enable_dns=true when enable_irsa=true,
  # so zone IDs will always be available when this module is created (count=1)
  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.enable_dns ? module.dns_certs_dev[0].public_zone_id : ""}",
          "arn:aws:route53:::hostedzone/${var.enable_dns ? module.dns_certs_dev[0].private_zone_id : ""}"
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
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-nonprod-external-dns-qa"
  oidc_provider_arn = local.cluster_oidc_provider_arn
  namespace         = "kube-system"
  service_account   = "external-dns-qa"

  # Note: Variable validation ensures enable_dns=true when enable_irsa=true,
  # so zone IDs will always be available when this module is created (count=1)
  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.enable_dns ? module.dns_certs_qa[0].public_zone_id : ""}",
          "arn:aws:route53:::hostedzone/${var.enable_dns ? module.dns_certs_dev[0].private_zone_id : ""}"
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
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-nonprod-cluster-autoscaler"
  oidc_provider_arn = local.cluster_oidc_provider_arn
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
          "ec2:DescribeLaunchTemplateVersions",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeCluster"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

module "irsa_aws_for_fluent_bit" {
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-nonprod-aws-for-fluent-bit"
  oidc_provider_arn = local.cluster_oidc_provider_arn
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

module "irsa_cloudwatch_agent" {
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-nonprod-cloudwatch-agent"
  oidc_provider_arn = local.cluster_oidc_provider_arn
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
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-nonprod-external-secrets"
  oidc_provider_arn = local.cluster_oidc_provider_arn
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

module "irsa_cert_manager" {
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-nonprod-cert-manager"
  oidc_provider_arn = local.cluster_oidc_provider_arn
  namespace         = "cert-manager"
  service_account   = "cert-manager"

  # Note: Variable validation ensures enable_dns=true when enable_irsa=true,
  # so zone IDs will always be available when this module is created (count=1)
  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange"
        ]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.enable_dns ? module.dns_certs_dev[0].public_zone_id : ""}",
          "arn:aws:route53:::hostedzone/${var.enable_dns ? module.dns_certs_qa[0].public_zone_id : ""}",
          "arn:aws:route53:::hostedzone/${var.enable_dns ? module.dns_certs_dev[0].private_zone_id : ""}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZonesByName",
          "route53:ListHostedZones"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

# Cognito User Pool
# Disabled by default (var.enable_cognito = false) to prevent user pool costs
module "cognito" {
  count  = var.enable_cognito ? 1 : 0
  source = "../../modules/cognito"

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
# Disabled by default (var.enable_github_oidc = false)
# NOTE: Requires var.enable_ecr=true as it references ECR repository ARNs
module "github_oidc" {
  count  = var.enable_github_oidc && var.enable_ecr ? 1 : 0
  source = "../../modules/github-oidc"

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
          module.ecr[0].repository_arns["cluckin-bell-app"]
        ]
      }
    ]
  })

  tags = local.common_tags
}

# Secrets Manager
# Disabled by default (var.enable_secrets = false) to prevent per-secret costs
module "secrets" {
  count  = var.enable_secrets ? 1 : 0
  source = "../../modules/secrets"

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

# Alerting Infrastructure
# Disabled by default (var.enable_alerting = false) to prevent SNS/CloudWatch alarm costs
module "alerting" {
  count  = var.enable_alerting ? 1 : 0
  source = "../../modules/alerting"

  environment        = "nonprod"
  alert_email        = "oscar21martinez88@gmail.com"
  alert_phone        = "+12298051449"
  log_retention_days = 7

  tags = local.common_tags
}