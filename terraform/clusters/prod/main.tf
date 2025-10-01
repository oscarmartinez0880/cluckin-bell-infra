###############################################################################
# Terraform and Provider Configuration
###############################################################################
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
  }
}

###############################################################################
# AWS Provider (prod account 346746763840)
###############################################################################
provider "aws" {
  alias   = "prod"
  region  = var.region
  profile = var.prod_profile
}

###############################################################################
# Networking - VPC (Prod)
###############################################################################
module "vpc" {
  source    = "terraform-aws-modules/vpc/aws"
  version   = "~> 5.8"
  providers = { aws = aws.prod }

  name = "cb-prod-use1"
  cidr = "10.61.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.61.1.0/24", "10.61.2.0/24", "10.61.3.0/24"]
  public_subnets  = ["10.61.101.0/24", "10.61.102.0/24", "10.61.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Project = "cluckn-bell"
    Env     = "prod"
  }
}

###############################################################################
# EKS Cluster (Prod)
###############################################################################
module "eks" {
  source    = "terraform-aws-modules/eks/aws"
  version   = "~> 20.8"
  providers = { aws = aws.prod }

  cluster_name                         = "cb-use1-prod"
  cluster_version                      = "1.33"
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.api_public_cidrs_prod

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  # Enable KMS secrets envelope encryption
  cluster_encryption_config = var.enable_cluster_encryption_prod ? [
    {
      provider_key_arn = aws_kms_key.eks_secrets_prod.arn
      resources        = ["secrets"]
    }
  ] : []

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["m5.large"]
    disk_size      = 50
  }

  eks_managed_node_groups = {
    default = { min_size = 3, max_size = 6, desired_size = 3 }
  }

  tags = {
    Project = "cluckn-bell"
    Env     = "prod"
  }

  depends_on = [aws_kms_key.eks_secrets_prod]
}

###############################################################################
# Kubernetes/Helm Providers (from EKS outputs)
###############################################################################
data "aws_eks_cluster" "prod" {
  provider = aws.prod
  name     = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "prod" {
  provider = aws.prod
  name     = module.eks.cluster_name
}

provider "kubernetes" {
  alias                  = "prod"
  host                   = data.aws_eks_cluster.prod.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.prod.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.prod.token
}

provider "helm" {
  alias = "prod"
  kubernetes {
    host                   = data.aws_eks_cluster.prod.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.prod.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.prod.token
  }
}

###############################################################################
# AWS Load Balancer Controller (ALB Controller) - Prod
###############################################################################
module "aws_load_balancer_controller" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-load-balancer-controller"
  version = "~> 20.8"

  providers = {
    aws        = aws.prod
    helm       = helm.prod
    kubernetes = kubernetes.prod
  }

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
}

###############################################################################
# ExternalDNS - Prod (scoped to apex zone)
###############################################################################
resource "aws_iam_role" "external_dns" {
  provider           = aws.prod
  name               = "cb-external-dns-prod"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume.json
}

data "aws_iam_policy_document" "external_dns_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:external-dns"]
    }
  }
}

# IAM policy for ExternalDNS moved to alb_extdns_hardening.tf to include internal zones
# resource "aws_iam_policy" "external_dns" {
#   provider = aws.prod
#   name     = "cb-external-dns-prod"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect   = "Allow",
#         Action   = ["route53:ChangeResourceRecordSets"],
#         Resource = ["arn:aws:route53:::hostedzone/${var.prod_apex_zone_id}"]
#       },
#       {
#         Effect   = "Allow",
#         Action   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:GetHostedZone"],
#         Resource = ["*"]
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "external_dns_attach" {
#   provider   = aws.prod
#   role       = aws_iam_role.external_dns.name
#   policy_arn = aws_iam_policy.external_dns.arn
# }

###############################################################################
# WAF v2 - Production Security Baseline
###############################################################################
module "waf_prod" {
  source = "../../../modules/wafv2"

  providers = { aws = aws.prod }

  name_prefix          = "cb-prod"
  environment          = "prod"
  enable_bot_control   = true # Enable Bot Control for production
  api_rate_limit       = 2000 # 2000 requests per 5 minutes for /api paths
  geo_block_countries  = []   # Empty by default, can be configured via variables
  admin_ip_allow_cidrs = []   # Empty by default, can be configured via variables
  enable_logging       = true # Enable WAF logging for production
  log_retention_days   = 30

  tags = {
    Project     = "cluckn-bell"
    Environment = "prod"
  }
}

###############################################################################
# CloudWatch Container Insights - Production
###############################################################################

# IAM role for CloudWatch Agent
module "cloudwatch_agent_irsa_prod" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  providers = { aws = aws.prod }

  role_name = "cb-cloudwatch-agent-prod"

  attach_cloudwatch_observability_policy = true

  oidc_providers = {
    prod = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:cloudwatch-agent"]
    }
  }

  tags = {
    Project     = "cluckn-bell"
    Environment = "prod"
  }
}

# IAM role for Fluent Bit
module "fluent_bit_irsa_prod" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  providers = { aws = aws.prod }

  role_name = "cb-fluent-bit-prod"

  attach_cloudwatch_observability_policy = true

  oidc_providers = {
    prod = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:aws-for-fluent-bit"]
    }
  }

  tags = {
    Project     = "cluckn-bell"
    Environment = "prod"
  }
}

# Container Insights configuration
module "container_insights_prod" {
  source = "../../../modules/monitoring"

  providers = {
    aws        = aws.prod
    kubernetes = kubernetes.prod
    helm       = helm.prod
  }

  cluster_name              = module.eks.cluster_name
  aws_region                = var.region
  cloudwatch_agent_role_arn = module.cloudwatch_agent_irsa_prod.iam_role_arn
  fluent_bit_role_arn       = module.fluent_bit_irsa_prod.iam_role_arn
  log_retention_days        = 30

  tags = {
    Project     = "cluckn-bell"
    Environment = "prod"
  }

  depends_on = [module.eks]
}

# ExternalDNS configuration moved to alb_extdns_hardening.tf for HA and internal zone support

###############################################################################
# Variables
###############################################################################
variable "region" {
  description = "AWS Region for the prod EKS cluster"
  type        = string
  default     = "us-east-1"
}

variable "prod_profile" {
  description = "AWS CLI profile for cluckin-bell-prod account (346746763840)"
  type        = string
  default     = "cluckin-bell-prod"
}

variable "prod_apex_zone_id" {
  description = "Route53 Hosted Zone ID for cluckn-bell.com"
  type        = string
}

# EKS API endpoint configuration for future CIDR restrictions
variable "api_public_cidrs_prod" {
  description = "List of CIDR blocks that can access the EKS public API endpoint (empty = allow all)"
  type        = list(string)
  default     = [] # Empty by default to allow all (current behavior)
}