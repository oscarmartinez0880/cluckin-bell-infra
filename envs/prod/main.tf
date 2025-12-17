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
    bucket = "cluckn-bell-tfstate-prod"
    key    = "prod/terraform.tfstate"
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
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

# DNS and Certificates - Production
# Enabled by default (var.enable_dns = true) as Route53 hosted zone costs are acceptable
#
# Route53 Hosted Zone Configuration:
# - Public Zone: cluckn-bell.com (internet-resolvable)
# - Private Zone: internal.cluckn-bell.com (VPC-associated)
#
# Migration Plan for Existing Misnamed Private Zone:
# 1. Apply new internal zone internal.cluckn-bell.com
# 2. Add required internal records (A, CNAME, TXT) mirroring old private records
# 3. Update application ingress hostnames to use *.internal.cluckn-bell.com
# 4. After validation, remove the old private cluckn-bell.com zone in a separate PR
module "dns_certs" {
  count  = var.enable_dns ? 1 : 0
  source = "../../modules/dns-certs"

  public_zone = {
    name   = var.public_zone_name
    create = var.create_public_zone
  }

  private_zone = {
    name    = var.internal_zone_name
    create  = var.create_internal_zone
    vpc_id  = local.vpc_id
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

  # Prevent accidental zone destruction in production
  allow_zone_destroy = false

  tags = merge(local.common_tags, {
    Managed = "Terraform"
    Service = "dns"
  })
}

# ECR Repository (shared)
# Disabled by default (var.enable_ecr = false) to prevent costs from image storage
module "ecr" {
  count  = var.enable_ecr ? 1 : 0
  source = "../../modules/ecr"

  repository_names = ["cluckin-bell-app"]
  max_image_count  = 10
  tags             = local.common_tags
}

# ECR Cross-Region Replication for Disaster Recovery
# Disabled by default (var.enable_ecr_replication = false)
# Requires ECR repositories to exist (var.enable_ecr = true)
resource "aws_ecr_replication_configuration" "prod" {
  count = var.enable_ecr && var.enable_ecr_replication ? 1 : 0

  replication_configuration {
    rule {
      dynamic "destination" {
        for_each = var.ecr_replication_regions
        content {
          region      = destination.value
          registry_id = data.aws_caller_identity.current.account_id
        }
      }
    }
  }

  depends_on = [module.ecr]
}

# Monitoring with CloudWatch and Container Insights
# Disabled by default (var.enable_monitoring = false) to prevent monitoring costs
# NOTE: When enabled, also enable var.enable_irsa=true for agent IRSA roles
module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "../../modules/monitoring"

  log_groups = {
    "/eks/prod/cluster" = {
      retention_in_days = 1 # Minimal retention to reduce costs
    }
    "/eks/prod/apps" = {
      retention_in_days = 1
    }
  }

  # Container Insights disabled by default as safety measure
  # Even when module is enabled, agents should be explicitly turned on
  container_insights = {
    enabled                   = false
    cluster_name              = "cluckn-bell-prod"
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

  role_name         = "cluckn-bell-prod-aws-load-balancer-controller"
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

module "irsa_external_dns" {
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-prod-external-dns"
  oidc_provider_arn = local.cluster_oidc_provider_arn
  namespace         = "kube-system"
  service_account   = "external-dns"

  # Note: Variable validation ensures enable_dns=true when enable_irsa=true,
  # so zone ID will always be available when this module is created (count=1)
  custom_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.enable_dns ? module.dns_certs[0].public_zone_id : ""}"
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

  role_name         = "cluckn-bell-prod-cluster-autoscaler"
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

  role_name         = "cluckn-bell-prod-aws-for-fluent-bit"
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
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/eks/prod/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

module "irsa_cloudwatch_agent" {
  count  = var.enable_irsa ? 1 : 0
  source = "../../modules/irsa"

  role_name         = "cluckn-bell-prod-cloudwatch-agent"
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

  role_name         = "cluckn-bell-prod-external-secrets"
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

  role_name         = "cluckn-bell-prod-cert-manager"
  oidc_provider_arn = local.cluster_oidc_provider_arn
  namespace         = "cert-manager"
  service_account   = "cert-manager"

  # Note: Variable validation ensures enable_dns=true when enable_irsa=true,
  # so zone ID will always be available when this module is created (count=1)
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
          "arn:aws:route53:::hostedzone/${var.enable_dns ? module.dns_certs[0].public_zone_id : ""}"
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

# Cognito User Pool (no users initially)
# Disabled by default (var.enable_cognito = false) to prevent user pool costs
module "cognito" {
  count  = var.enable_cognito ? 1 : 0
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
# Disabled by default (var.enable_github_oidc = false)
# NOTE: Requires var.enable_ecr=true as it references ECR repository ARNs
module "github_oidc" {
  count  = var.enable_github_oidc && var.enable_ecr ? 1 : 0
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

# Secrets Manager Cross-Region Replication for Disaster Recovery
# Disabled by default (var.enable_secrets_replication = false)
# Requires Secrets Manager secrets to exist (var.enable_secrets = true)
# Note: Replicas are created for each secret in specified regions
resource "aws_secretsmanager_secret_replica" "prod" {
  for_each = var.enable_secrets && var.enable_secrets_replication ? {
    for combo in flatten([
      for secret_name, secret_config in module.secrets[0].secret_arns : [
        for region in var.secrets_replication_regions : {
          key         = "${secret_name}-${region}"
          secret_id   = secret_config
          region      = region
          secret_name = secret_name
        }
      ]
    ]) : combo.key => combo
  } : {}

  replica_region = each.value.region
  secret_id      = each.value.secret_id

  depends_on = [module.secrets]
}

# Alerting Infrastructure
# Disabled by default (var.enable_alerting = false) to prevent SNS/CloudWatch alarm costs
module "alerting" {
  count  = var.enable_alerting ? 1 : 0
  source = "../../modules/alerting"

  environment        = "prod"
  alert_email        = "oscar21martinez88@gmail.com"
  alert_phone        = "+12298051449"
  log_retention_days = 7

  tags = local.common_tags
}

# Karpenter - Just-in-Time Node Provisioning
# Disabled by default (var.enable_karpenter = false)
# Requires EKS cluster to exist with OIDC provider
# Karpenter replaces Cluster Autoscaler for more efficient node provisioning
module "karpenter" {
  count  = var.enable_karpenter ? 1 : 0
  source = "../../modules/karpenter"

  cluster_name              = local.cluster_name
  cluster_endpoint          = local.cluster_endpoint
  cluster_oidc_provider_arn = local.cluster_oidc_provider_arn
  namespace                 = var.karpenter_namespace
  service_account_name      = "karpenter"
  chart_version             = var.karpenter_version
  node_iam_role_name        = "${local.cluster_name}-node-role"
  enable_pod_identity       = true

  tags = local.common_tags
}

# ============================================================================
# Disaster Recovery Enhancements (Optional)
# ============================================================================

# ECR Cross-Region Replication
# Disabled by default (var.enable_ecr_replication = false)
# When enabled, automatically replicates ECR images to specified regions
module "ecr_replication" {
  count  = var.enable_ecr_replication && length(var.ecr_replication_regions) > 0 ? 1 : 0
  source = "../../modules/ecr-replication"

  replication_regions = var.ecr_replication_regions
}

# Secrets Manager Replication
# Disabled by default (var.enable_secrets_replication = false)
# When enabled, replicates critical secrets to specified regions
# Note: Requires secrets to be created via the secrets module
# 
# Example configuration:
# secrets = {
#   "prod/database/master" = {
#     description      = "Master database credentials"
#     static_values    = { username = "admin" }
#     generated_values = { password = "" }
#   }
# }
module "secrets_replication" {
  count  = var.enable_secrets && var.enable_secrets_replication && length(var.secrets_replication_regions) > 0 ? 1 : 0
  source = "../../modules/secrets"

  secrets = {} # TODO: Configure with actual secrets to replicate when enabling DR

  enable_replication  = true
  replication_regions = var.secrets_replication_regions

  tags = merge(local.common_tags, {
    Service = "secrets-dr"
  })
}

# Route53 DNS Failover
# Disabled by default (var.enable_dns_failover = false)
# When enabled, creates health checks and failover DNS records
module "dns_failover" {
  count  = var.enable_dns && var.enable_dns_failover && length(var.failover_records) > 0 ? 1 : 0
  source = "../../modules/dns-failover"

  hosted_zone_id   = var.enable_dns ? module.dns_certs[0].public_zone_id : ""
  failover_records = var.failover_records

  tags = merge(local.common_tags, {
    Service = "dns-failover"
  })
}