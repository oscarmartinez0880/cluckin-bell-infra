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
# AWS Providers (per account)
# - cluckin-bell-qa (dev/qa shared cluster) - 264765154707
# - cluckin-bell-prod (prod cluster)         - 346746763840
###############################################################################
provider "aws" {
  alias   = "devqa"
  region  = var.region
  profile = var.devqa_profile
}

provider "aws" {
  alias   = "prod"
  region  = var.region
  profile = var.prod_profile
}

###############################################################################
# Networking - VPCs
###############################################################################

# Shared Dev/QA VPC in cluckin-bell-qa
module "vpc_devqa" {
  source    = "terraform-aws-modules/vpc/aws"
  version   = "~> 5.8"
  providers = { aws = aws.devqa }

  name = "cb-devqa-use1"
  cidr = "10.60.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.60.1.0/24", "10.60.2.0/24", "10.60.3.0/24"]
  public_subnets  = ["10.60.101.0/24", "10.60.102.0/24", "10.60.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Project = "cluckn-bell"
    Env     = "shared-devqa"
  }
}

# Prod VPC in cluckin-bell-prod
module "vpc_prod" {
  source    = "terraform-aws-modules/vpc/aws"
  version   = "~> 5.8"
  providers = { aws = aws.prod }

  name = "cb-prod-use1"
  cidr = "10.70.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.70.1.0/24", "10.70.2.0/24", "10.70.3.0/24"]
  public_subnets  = ["10.70.101.0/24", "10.70.102.0/24", "10.70.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  tags = {
    Project = "cluckn-bell"
    Env     = "prod"
  }
}

###############################################################################
# EKS Clusters (Kubernetes >= 1.30)
###############################################################################

# Shared Dev/QA EKS Cluster
module "eks_devqa" {
  count     = var.manage_eks ? 1 : 0
  source    = "terraform-aws-modules/eks/aws"
  version   = "~> 20.8"
  providers = { aws = aws.devqa }

  cluster_name                         = "cb-use1-shared"
  cluster_version                      = "1.33"
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.api_public_cidrs_devqa

  vpc_id     = module.vpc_devqa.vpc_id
  subnet_ids = module.vpc_devqa.private_subnets

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  # KMS encryption disabled by default for dev/qa (can be enabled later)
  cluster_encryption_config = var.enable_cluster_encryption_devqa ? [
    {
      provider_key_arn = var.kms_key_arn_devqa # Would need to be created if enabled
      resources        = ["secrets"]
    }
  ] : []

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["t3.medium"]
    disk_size      = 50
  }

  eks_managed_node_groups = {
    default = {
      min_size     = 2
      max_size     = 5
      desired_size = 2
    }
  }

  tags = {
    Project = "cluckn-bell"
    Env     = "shared-devqa"
  }
}

# Prod EKS Cluster
module "eks_prod" {
  count     = var.manage_eks ? 1 : 0
  source    = "terraform-aws-modules/eks/aws"
  version   = "~> 20.8"
  providers = { aws = aws.prod }

  cluster_name                   = "cb-use1-prod"
  cluster_version                = "1.33"
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc_prod.vpc_id
  subnet_ids = module.vpc_prod.private_subnets

  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = ["m5.large"]
    disk_size      = 50
  }

  eks_managed_node_groups = {
    default = {
      min_size     = 2
      max_size     = 5
      desired_size = 2
    }
  }

  tags = {
    Project = "cluckn-bell"
    Env     = "prod"
  }
}

###############################################################################
# Kubernetes/Helm Providers (per cluster)
###############################################################################

# Dev/QA cluster auth and providers
data "aws_eks_cluster" "devqa" {
  count    = var.manage_eks ? 1 : 0
  provider = aws.devqa
  name     = module.eks_devqa[0].cluster_name
}

data "aws_eks_cluster_auth" "devqa" {
  count    = var.manage_eks ? 1 : 0
  provider = aws.devqa
  name     = module.eks_devqa[0].cluster_name
}

provider "kubernetes" {
  alias                  = "devqa"
  host                   = var.manage_eks ? data.aws_eks_cluster.devqa[0].endpoint : ""
  cluster_ca_certificate = var.manage_eks ? base64decode(data.aws_eks_cluster.devqa[0].certificate_authority[0].data) : null
  token                  = var.manage_eks ? data.aws_eks_cluster_auth.devqa[0].token : ""
}

provider "helm" {
  alias = "devqa"
  kubernetes {
    host                   = var.manage_eks ? data.aws_eks_cluster.devqa[0].endpoint : ""
    cluster_ca_certificate = var.manage_eks ? base64decode(data.aws_eks_cluster.devqa[0].certificate_authority[0].data) : null
    token                  = var.manage_eks ? data.aws_eks_cluster_auth.devqa[0].token : ""
  }
}

# Prod cluster auth and providers
data "aws_eks_cluster" "prod" {
  count    = var.manage_eks ? 1 : 0
  provider = aws.prod
  name     = module.eks_prod[0].cluster_name
}

data "aws_eks_cluster_auth" "prod" {
  count    = var.manage_eks ? 1 : 0
  provider = aws.prod
  name     = module.eks_prod[0].cluster_name
}

provider "kubernetes" {
  alias                  = "prod"
  host                   = var.manage_eks ? data.aws_eks_cluster.prod[0].endpoint : ""
  cluster_ca_certificate = var.manage_eks ? base64decode(data.aws_eks_cluster.prod[0].certificate_authority[0].data) : null
  token                  = var.manage_eks ? data.aws_eks_cluster_auth.prod[0].token : ""
}

provider "helm" {
  alias = "prod"
  kubernetes {
    host                   = var.manage_eks ? data.aws_eks_cluster.prod[0].endpoint : ""
    cluster_ca_certificate = var.manage_eks ? base64decode(data.aws_eks_cluster.prod[0].certificate_authority[0].data) : null
    token                  = var.manage_eks ? data.aws_eks_cluster_auth.prod[0].token : ""
  }
}

###############################################################################
# AWS Load Balancer Controller (ALB Controller) - Dev/QA and Prod
###############################################################################

module "aws_load_balancer_controller_devqa" {
  count   = var.manage_eks ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/aws-load-balancer-controller"
  version = "~> 20.8"

  providers = {
    aws        = aws.devqa
    helm       = helm.devqa
    kubernetes = kubernetes.devqa
  }

  cluster_name      = module.eks_devqa[0].cluster_name
  oidc_provider_arn = module.eks_devqa[0].oidc_provider_arn
}

module "aws_load_balancer_controller_prod" {
  count   = var.manage_eks ? 1 : 0
  source  = "terraform-aws-modules/eks/aws//modules/aws-load-balancer-controller"
  version = "~> 20.8"

  providers = {
    aws        = aws.prod
    helm       = helm.prod
    kubernetes = kubernetes.prod
  }

  cluster_name      = module.eks_prod[0].cluster_name
  oidc_provider_arn = module.eks_prod[0].oidc_provider_arn
}

###############################################################################
# ExternalDNS - Dev/QA cluster (scoped to dev/qa sub-zones)
###############################################################################

# IRSA role for ExternalDNS
resource "aws_iam_role" "external_dns_devqa" {
  count              = var.manage_eks ? 1 : 0
  provider           = aws.devqa
  name               = "cb-external-dns-devqa"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_devqa[0].json
}

data "aws_iam_policy_document" "external_dns_assume_devqa" {
  count = var.manage_eks ? 1 : 0
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks_devqa[0].oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks_devqa[0].cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:external-dns"]
    }
  }
}

# IAM policy for ExternalDNS moved to alb_extdns_hardening.tf to include internal zones
# resource "aws_iam_policy" "external_dns_devqa" {
#   provider = aws.devqa
#   name     = "cb-external-dns-devqa"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect   = "Allow",
#         Action   = ["route53:ChangeResourceRecordSets"],
#         Resource = [
#           "arn:aws:route53:::hostedzone/${var.dev_zone_id}",
#           "arn:aws:route53:::hostedzone/${var.qa_zone_id}"
#         ]
#       },
#       {
#         Effect   = "Allow",
#         Action   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:GetHostedZone"],
#         Resource = ["*"]
#       }
#     ]
#   })
# }

# resource "aws_iam_role_policy_attachment" "external_dns_attach_devqa" {
#   provider   = aws.devqa
#   role       = aws_iam_role.external_dns_devqa.name
#   policy_arn = aws_iam_policy.external_dns_devqa.arn
# }

# ExternalDNS configuration moved to alb_extdns_hardening.tf for HA and internal zone support

###############################################################################
# WAF v2 - Dev/QA Security Baseline
###############################################################################
module "waf_devqa" {
  source = "../../../modules/wafv2"

  providers = { aws = aws.devqa }

  name_prefix          = "cb-devqa"
  environment          = "devqa"
  enable_bot_control   = false # Bot Control disabled for dev/qa to reduce costs
  api_rate_limit       = 5000  # Higher rate limit for dev/qa testing
  geo_block_countries  = []    # Empty by default, can be configured via variables
  admin_ip_allow_cidrs = []    # Empty by default, can be configured via variables
  enable_logging       = false # Logging disabled for dev/qa to reduce costs
  log_retention_days   = 7

  tags = {
    Project     = "cluckn-bell"
    Environment = "devqa"
  }
}

###############################################################################
# CloudWatch Container Insights - Dev/QA
###############################################################################

# IAM role for CloudWatch Agent (DevQA)
module "cloudwatch_agent_irsa_devqa" {
  count  = var.manage_eks ? 1 : 0
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  providers = { aws = aws.devqa }

  role_name = "cb-cloudwatch-agent-devqa"

  attach_cloudwatch_observability_policy = true

  oidc_providers = {
    devqa = {
      provider_arn               = module.eks_devqa[0].oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:cloudwatch-agent"]
    }
  }

  tags = {
    Project     = "cluckn-bell"
    Environment = "devqa"
  }
}

# IAM role for Fluent Bit (DevQA)
module "fluent_bit_irsa_devqa" {
  count  = var.manage_eks ? 1 : 0
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  providers = { aws = aws.devqa }

  role_name = "cb-fluent-bit-devqa"

  attach_cloudwatch_observability_policy = true

  oidc_providers = {
    devqa = {
      provider_arn               = module.eks_devqa[0].oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:aws-for-fluent-bit"]
    }
  }

  tags = {
    Project     = "cluckn-bell"
    Environment = "devqa"
  }
}

# Container Insights configuration (DevQA)
module "container_insights_devqa" {
  count  = var.manage_eks ? 1 : 0
  source = "../../../modules/monitoring"

  providers = {
    aws        = aws.devqa
    kubernetes = kubernetes.devqa
    helm       = helm.devqa
  }

  cluster_name              = module.eks_devqa[0].cluster_name
  aws_region                = var.region
  cloudwatch_agent_role_arn = module.cloudwatch_agent_irsa_devqa[0].iam_role_arn
  fluent_bit_role_arn       = module.fluent_bit_irsa_devqa[0].iam_role_arn
  log_retention_days        = 7 # Shorter retention for dev/qa

  tags = {
    Project     = "cluckn-bell"
    Environment = "devqa"
  }

  depends_on = [module.eks_devqa]
}

###############################################################################
# Variables
###############################################################################
variable "manage_eks" {
  description = "Whether to manage EKS clusters via Terraform (disabled by default - use eksctl instead)"
  type        = bool
  default     = false
}

variable "region" {
  description = "AWS Region for all EKS clusters"
  type        = string
  default     = "us-east-1"
}

variable "devqa_profile" {
  description = "AWS CLI profile for cluckin-bell-qa account (264765154707)"
  type        = string
  default     = "cluckin-bell-qa"
}

variable "prod_profile" {
  description = "AWS CLI profile for cluckin-bell-prod account (346746763840)"
  type        = string
  default     = "cluckin-bell-prod"
}

variable "dev_zone_id" {
  description = "Route53 Hosted Zone ID for dev.cluckn-bell.com"
  type        = string
}

variable "qa_zone_id" {
  description = "Route53 Hosted Zone ID for qa.cluckn-bell.com"
  type        = string
}

# EKS API endpoint configuration for future CIDR restrictions
variable "api_public_cidrs_devqa" {
  description = "List of CIDR blocks that can access the EKS public API endpoint (empty = allow all)"
  type        = list(string)
  default     = [] # Empty by default to allow all (current behavior)
}

# KMS encryption variables (disabled by default for dev/qa)
variable "enable_cluster_encryption_devqa" {
  description = "Enable EKS cluster envelope encryption for secrets in dev/qa"
  type        = bool
  default     = false
}

variable "kms_key_arn_devqa" {
  description = "KMS key ARN for EKS secrets encryption in dev/qa (only needed if encryption enabled)"
  type        = string
  default     = ""
}