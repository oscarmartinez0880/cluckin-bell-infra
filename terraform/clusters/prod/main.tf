provider "aws" {
  alias  = "prod"
  region = "us-east-1"
}

module "vpc" {
  source    = "terraform-aws-modules/vpc/aws"
  version   = "~> 5.8"
  providers = { aws = aws.prod }

  name            = "cb-prod-use1"
  cidr            = "10.61.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.61.1.0/24", "10.61.2.0/24", "10.61.3.0/24"]
  public_subnets  = ["10.61.101.0/24", "10.61.102.0/24", "10.61.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = { Project = "cluckn-bell", Env = "prod" }
}

module "eks" {
  source    = "terraform-aws-modules/eks/aws"
  version   = "~> 20.8"
  providers = { aws = aws.prod }

  cluster_name                   = "cb-use1-prod"
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
    default = { min_size = 3, max_size = 6, desired_size = 3 }
  }

  tags = { Project = "cluckn-bell", Env = "prod" }
}

data "aws_eks_cluster" "this" {
  provider = aws.prod
  name     = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  provider = aws.prod
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

module "aws_load_balancer_controller" {
  source    = "terraform-aws-modules/eks/aws//modules/aws-load-balancer-controller"
  version   = "~> 20.8"
  providers = { aws = aws.prod }

  cluster_name              = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  create_policy             = true
}

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
      variable = replace(module.eks.cluster_oidc_issuer_url, "https://", "") + ":sub"
      values   = ["system:serviceaccount:default:external-dns"]
    }
  }
}

resource "aws_iam_policy" "external_dns" {
  provider = aws.prod
  name     = "cb-external-dns-prod"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["route53:ChangeResourceRecordSets"],
        Resource = ["arn:aws:route53:::hostedzone/${var.prod_apex_zone_id}"]
      },
      {
        Effect   = "Allow",
        Action   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:GetHostedZone"],
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns_attach" {
  provider   = aws.prod
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
    txtOwnerId    = "cb-prod-external-dns",
    domainFilters = ["cluckn-bell.com"],
    serviceAccount = {
      annotations = { "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn },
      create      = true,
      name        = "external-dns"
    }
  })]
}

variable "prod_apex_zone_id" { type = string }