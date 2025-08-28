provider "aws" {
  alias  = "devqa"
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"
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

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  providers = { aws = aws.devqa }

  cluster_name                   = "cb-use1-shared"
  cluster_version                = "1.30"
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

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
    Env     = "shared-devqa"
  }
}

# K8s providers configured from EKS outputs (for helm installs)
data "aws_eks_cluster" "this" {
  provider = aws.devqa
  name     = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  provider = aws.devqa
  name     = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# AWS Load Balancer Controller
module "aws_load_balancer_controller" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-load-balancer-controller"
  version = "~> 20.8"

  providers = { aws = aws.devqa }

  cluster_name                = module.eks.cluster_name
  cluster_oidc_provider_arn   = module.eks.oidc_provider_arn
  create_policy               = true
}

# ExternalDNS (scoped to dev/qa sub-zones)
resource "aws_iam_role" "external_dns" {
  provider           = aws.devqa
  name               = "cb-external-dns-devqa"
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
      variable = replace(module.eks.cluster_oidc_issuer_url, "https://", "") + ":sub"
      values   = ["system:serviceaccount:default:external-dns"]
    }
  }
}

resource "aws_iam_policy" "external_dns" {
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
        Effect = "Allow",
        Action = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:GetHostedZone"],
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns_attach" {
  provider  = aws.devqa
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.15.0"

  values = [yamlencode({
    provider      = "aws",
    policy        = "upsert-only",
    txtOwnerId    = "cb-devqa-external-dns",
    domainFilters = ["dev.cluckn-bell.com", "qa.cluckn-bell.com"],
    serviceAccount = {
      annotations = { "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn },
      create      = true,
      name        = "external-dns"
    }
  })]
}

variable "dev_zone_id" { type = string }
variable "qa_zone_id"  { type = string }