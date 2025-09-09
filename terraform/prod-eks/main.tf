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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    # Configuration will be loaded from backend.hcl
    # bucket = "cluckn-bell-tfstate-prod"
    # key    = "eks/prod-cluster.tfstate"
    # region = "us-east-1"
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = var.tags
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# EKS Cluster with existing VPC and subnets
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "cluckn-bell-prod"
  cluster_version = var.cluster_version

  # Network configuration - use existing VPC and subnets
  vpc_id                   = var.vpc_id
  subnet_ids               = concat(var.private_subnet_ids, var.public_subnet_ids)
  control_plane_subnet_ids = var.private_subnet_ids

  # Cluster endpoint configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  # TODO: Restrict public endpoint access CIDRs for security hardening
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Enable logging for all control plane log types
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    # Production node group
    prod = {
      name           = "cluckn-bell-prod-prod"
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      min_size     = 2
      max_size     = 6
      desired_size = 3

      # Use only private subnets for worker nodes
      subnet_ids = var.private_subnet_ids

      labels = {
        env         = "prod"
        environment = "prod"
        nodegroup   = "prod"
      }

      tags = merge(var.tags, {
        Environment = "prod"
        NodeGroup   = "prod"
      })
    }
  }

  # Core EKS Add-ons with compatible versions
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  tags = merge(var.tags, {
    Environment = "prod"
    ClusterType = "dedicated"
  })
}

# Post-Apply Instructions (in comments for documentation)
#
# 1. Update kubeconfig:
#    aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-prod --profile cluckin-bell-prod
#
# 2. Bootstrap Argo CD from application repo
#
# 3. Sync platform-addons app to deploy ExternalDNS in prod
#
# 4. Validate ExternalDNS:
#    kubectl -n external-dns logs deploy/external-dns | head