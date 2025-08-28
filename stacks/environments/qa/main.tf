terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# Local variables for naming consistency
locals {
  environment  = "qa"
  region       = "us-east-1"
  cluster_name = "cb-qa-use1"
  namespace    = "cluckin-bell"

  # VPC configuration
  vpc_cidr             = "10.1.0.0/16"
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
  private_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24"]

  tags = {
    Environment = local.environment
    Project     = "cluckin-bell"
    ManagedBy   = "terraform"
    Region      = local.region
  }
}

provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

# VPC for qa environment
module "vpc" {
  source = "../../../modules/vpc"

  name                 = "${local.environment}-cluckin-bell"
  vpc_cidr             = local.vpc_cidr
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
  enable_nat_gateway   = true
  enable_vpc_endpoints = true

  tags = local.tags
}

# Kubernetes and Helm providers
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.public_subnet_ids

  # Enable IRSA
  enable_irsa = true

  # Cluster endpoint configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Cluster encryption
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    # Linux node group for core workloads and platform components
    linux = {
      name = "${local.cluster_name}-linux-nodes"

      instance_types = var.linux_node_instance_types
      ami_type       = "AL2_x86_64"

      min_size     = var.linux_node_min_size
      max_size     = var.linux_node_max_size
      desired_size = var.linux_node_desired_size

      labels = {
        role = "linux-workload"
        os   = "linux"
      }

      tags = merge(local.tags, {
        app   = "cluckin-bell"
        stack = "platform-eks"
        tier  = "linux"
      })
    }
  }

  # Cluster add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  tags = merge(local.tags, {
    Stack = "platform-eks"
  })
}

# KMS key for EKS cluster encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key for ${local.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.tags, {
    Name  = "${local.environment}-eks-encryption-key"
    Stack = "platform-eks"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.environment}-eks-encryption-key"
  target_key_id = aws_kms_key.eks.key_id
}

# VPC CNI IRSA role
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.environment}-vpc-cni-irsa"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  vpc_cni_enable_ipv6   = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = merge(local.tags, {
    Stack = "platform-eks"
  })
}

# IRSA roles for Kubernetes controllers
module "aws_load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.environment}-aws-load-balancer-controller-irsa"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:aws-load-balancer-controller"]
    }
  }

  tags = merge(local.tags, {
    Stack = "platform-eks"
  })
}

module "cert_manager_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.environment}-cert-manager-irsa"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:cert-manager"]
    }
  }

  tags = merge(local.tags, {
    Stack = "platform-eks"
  })
}

resource "aws_iam_role_policy" "cert_manager_route53" {
  name = "${local.environment}-cert-manager-route53"
  role = module.cert_manager_irsa.iam_role_name

  policy = jsonencode({
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
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      }
    ]
  })
}

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.environment}-external-dns-irsa"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:external-dns"]
    }
  }

  tags = merge(local.tags, {
    Stack = "platform-eks"
  })
}

resource "aws_iam_role_policy" "external_dns_route53" {
  name = "${local.environment}-external-dns-route53"
  role = module.external_dns_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      }
    ]
  })
}

# IRSA role for Argo CD repo-server to access CodeCommit
module "argocd_repo_server_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.environment}-argocd-repo-server-irsa"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.namespace}:argocd-repo-server"]
    }
  }

  tags = merge(local.tags, {
    Stack = "gitops"
  })
}

# IAM policy for CodeCommit read-only access
resource "aws_iam_policy" "argocd_codecommit_access" {
  name        = "${local.environment}-argocd-codecommit-access"
  description = "Policy for Argo CD to access CodeCommit repository"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPull",
          "codecommit:GetBranch",
          "codecommit:GetCommit",
          "codecommit:GetRepository",
          "codecommit:ListBranches",
          "codecommit:ListRepositories",
          "codecommit:BatchGetCommits",
          "codecommit:BatchGetRepositories"
        ]
        Resource = "arn:aws:codecommit:${local.region}:*:cluckin-bell"
      }
    ]
  })

  tags = merge(local.tags, {
    Stack = "gitops"
  })
}

# Attach policy to IRSA role
resource "aws_iam_role_policy_attachment" "argocd_codecommit_access" {
  policy_arn = aws_iam_policy.argocd_codecommit_access.arn
  role       = module.argocd_repo_server_irsa.iam_role_name
}

# Create the cluckin-bell namespace
resource "kubernetes_namespace" "cluckin_bell" {
  metadata {
    name = local.namespace
    labels = {
      name = local.namespace
    }
  }

  depends_on = [module.eks]
}

# Deploy Kubernetes controllers
module "k8s_controllers" {
  source = "../../../modules/k8s-controllers"

  cluster_name = module.eks.cluster_name
  environment  = local.environment
  aws_region   = local.region
  vpc_id       = module.vpc.vpc_id
  namespace    = local.namespace

  # Enable controllers
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller
  enable_cert_manager                 = var.enable_cert_manager
  enable_external_dns                 = var.enable_external_dns
  enable_argocd                       = false # We use separate argocd module

  # IRSA role ARNs
  aws_load_balancer_controller_role_arn = module.aws_load_balancer_controller_irsa.iam_role_arn
  cert_manager_role_arn                 = module.cert_manager_irsa.iam_role_arn
  external_dns_role_arn                 = module.external_dns_irsa.iam_role_arn

  # Configuration
  letsencrypt_email = var.letsencrypt_email
  domain_filter     = "qa.cluckin-bell.com"

  # Dependencies
  node_groups = module.eks.eks_managed_node_groups

  depends_on = [
    module.eks,
    kubernetes_namespace.cluckin_bell,
    module.aws_load_balancer_controller_irsa,
    module.cert_manager_irsa,
    module.external_dns_irsa
  ]
}

# Deploy ArgoCD for GitOps
module "argocd" {
  source = "../../../modules/argocd"

  cluster_name                = module.eks.cluster_name
  namespace                   = local.namespace
  environment                 = local.environment
  git_repository              = "https://github.com/oscarmartinez0880/cluckin-bell.git"
  git_path                    = "k8s/qa"
  argocd_repo_server_role_arn = module.argocd_repo_server_irsa.iam_role_arn

  depends_on = [
    kubernetes_namespace.cluckin_bell,
    module.k8s_controllers,
    module.argocd_repo_server_irsa
  ]
}