###############################################################################
# Terraform and Provider Configuration
###############################################################################
terraform {
  required_version = "~> 1.13.1"

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
  default_tags {
    tags = {
      Project = "cluckn-bell"
      Owner   = var.owner_tag
      Env     = "shared-devqa"
    }
  }
}

provider "aws" {
  alias   = "prod"
  region  = var.region
  profile = var.prod_profile
  default_tags {
    tags = {
      Project = "cluckn-bell"
      Owner   = var.owner_tag
      Env     = "prod"
    }
  }
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
  source    = "terraform-aws-modules/eks/aws"
  version   = "~> 20.8"
  providers = { aws = aws.devqa }

  cluster_name                   = "cb-use1-shared"
  cluster_version                = "1.30"
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc_devqa.vpc_id
  subnet_ids = module.vpc_devqa.private_subnets

  enable_irsa                                = true
  enable_cluster_creator_admin_permissions   = true

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

  # Cluster encryption configuration
  cluster_encryption_config = [{ 
    provider_key_arn = aws_kms_key.eks_secrets.arn
    resources = ["secrets"] 
  }]

  # Cluster endpoint controls
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = var.api_public_cidrs

  tags = {
    Project = "cluckn-bell"
    Env     = "shared-devqa"
  }
}

# Prod EKS Cluster
module "eks_prod" {
  source    = "terraform-aws-modules/eks/aws"
  version   = "~> 20.8"
  providers = { aws = aws.prod }

  cluster_name                   = "cb-use1-prod"
  cluster_version                = "1.30"
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
  provider = aws.devqa
  name     = module.eks_devqa.cluster_name
}

data "aws_eks_cluster_auth" "devqa" {
  provider = aws.devqa
  name     = module.eks_devqa.cluster_name
}

provider "kubernetes" {
  alias                  = "devqa"
  host                   = data.aws_eks_cluster.devqa.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.devqa.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.devqa.token
}

provider "helm" {
  alias = "devqa"
  kubernetes {
    host                   = data.aws_eks_cluster.devqa.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.devqa.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.devqa.token
  }
}

# Prod cluster auth and providers
data "aws_eks_cluster" "prod" {
  provider = aws.prod
  name     = module.eks_prod.cluster_name
}

data "aws_eks_cluster_auth" "prod" {
  provider = aws.prod
  name     = module.eks_prod.cluster_name
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
# AWS Load Balancer Controller (ALB Controller) - Dev/QA and Prod
###############################################################################

# NOTE: ALB Controller configurations moved to dedicated hardening files:
# - devqa: alb_extdns_hardening.tf
# - prod: alb_extdns_hardening.tf

###############################################################################
# ExternalDNS - Dev/QA cluster (scoped to dev/qa sub-zones)
###############################################################################

# IRSA role for ExternalDNS
resource "aws_iam_role" "external_dns_devqa" {
  provider           = aws.devqa
  name               = "cb-external-dns-devqa"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_devqa.json
}

data "aws_iam_policy_document" "external_dns_assume_devqa" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks_devqa.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks_devqa.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:external-dns"]
    }
  }
}

resource "aws_iam_policy" "external_dns_devqa" {
  provider = aws.devqa
  name     = "cb-external-dns-devqa"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["route53:ChangeResourceRecordSets"],
        Resource = [
          "arn:aws:route53:::hostedzone/${var.dev_zone_id}",
          "arn:aws:route53:::hostedzone/${var.qa_zone_id}"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:GetHostedZone"],
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns_attach_devqa" {
  provider   = aws.devqa
  role       = aws_iam_role.external_dns_devqa.name
  policy_arn = aws_iam_policy.external_dns_devqa.arn
}

# NOTE: ExternalDNS helm_release moved to alb_extdns_hardening.tf with HA and PDB configuration

###############################################################################
# Variables
###############################################################################
variable "region" {
  description = "AWS Region for all EKS clusters"
  type        = string
  default     = "us-east-1"
}

variable "owner_tag" {
  description = "Owner tag for all resources"
  type        = string
  default     = "oscarmartinez0880"
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