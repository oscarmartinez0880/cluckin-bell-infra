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
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "cluckin-bell"
      ManagedBy   = "terraform"
    }
  }
}

# Data sources for existing VPC and subnets (assuming they exist)
data "aws_vpc" "main" {
  tags = {
    Name = "${var.environment}-vpc"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Type = "private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Type = "public"
  }
}

# EKS Cluster with Windows support
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.environment}-cluckin-bell"
  cluster_version = var.kubernetes_version

  vpc_id                   = data.aws_vpc.main.id
  subnet_ids               = data.aws_subnets.private.ids
  control_plane_subnet_ids = data.aws_subnets.public.ids

  # Enable Windows support through cluster addons and proper configuration

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
    # Linux node group for core DaemonSets and other Linux workloads
    linux = {
      name = "${var.environment}-linux-nodes"

      instance_types = var.linux_node_instance_types
      ami_type       = "AL2_x86_64"

      min_size     = var.linux_node_min_size
      max_size     = var.linux_node_max_size
      desired_size = var.linux_node_desired_size

      labels = {
        role = "linux-workload"
        os   = "linux"
      }

      tags = {
        app   = "cluckin-bell"
        stack = "platform-eks"
        tier  = "linux"
      }
    }

    # Windows node group for Sitecore CM/CD pods
    windows = {
      name = "${var.environment}-windows-nodes"

      instance_types = var.windows_node_instance_types
      ami_type       = "WINDOWS_CORE_2022_x86_64"

      min_size     = var.windows_node_min_size
      max_size     = var.windows_node_max_size
      desired_size = var.windows_node_desired_size

      labels = {
        role = "windows-workload"
        os   = "windows"
      }

      taints = {
        windows = {
          key    = "os"
          value  = "windows"
          effect = "NO_SCHEDULE"
        }
      }

      tags = {
        app   = "cluckin-bell"
        stack = "platform-eks"
        tier  = "windows"
      }
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
      configuration_values = jsonencode({
        env = {
          # Enable Windows support in VPC CNI
          ENABLE_WINDOWS_IPAM = "true"
        }
      })
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # Additional security group rules
  node_security_group_additional_rules = {
    ingress_windows_netbios = {
      description = "Windows NetBIOS Name Service"
      protocol    = "udp"
      from_port   = 137
      to_port     = 137
      type        = "ingress"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
    }
    ingress_windows_netbios_session = {
      description = "Windows NetBIOS Session Service"
      protocol    = "tcp"
      from_port   = 139
      to_port     = 139
      type        = "ingress"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
    }
    ingress_windows_smb = {
      description = "Windows SMB"
      protocol    = "tcp"
      from_port   = 445
      to_port     = 445
      type        = "ingress"
      cidr_blocks = [data.aws_vpc.main.cidr_block]
    }
  }

  tags = {
    Environment = var.environment
    Project     = "cluckin-bell"
    Stack       = "platform-eks"
  }
}

# KMS key for EKS cluster encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key for ${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name        = "${var.environment}-eks-encryption-key"
    Environment = var.environment
    Project     = "cluckin-bell"
    Stack       = "platform-eks"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.environment}-eks-encryption-key"
  target_key_id = aws_kms_key.eks.key_id
}

# VPC CNI IRSA role
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.environment}-vpc-cni-irsa"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true
  vpc_cni_enable_ipv6   = false

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = {
    Environment = var.environment
    Project     = "cluckin-bell"
    Stack       = "platform-eks"
  }
}

# Ensure ECR access for node groups
resource "aws_iam_role_policy_attachment" "linux_node_group_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = module.eks.eks_managed_node_groups["linux"].iam_role_name
}

resource "aws_iam_role_policy_attachment" "windows_node_group_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = module.eks.eks_managed_node_groups["windows"].iam_role_name
}

# ECR repositories for Sitecore components
resource "aws_ecr_repository" "repos" {
  for_each = toset(var.ecr_repositories)
  name     = "${var.environment}-cluckin-bell-${each.value}"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = var.environment
    Project     = "cluckin-bell"
    Stack       = "platform-eks"
    Component   = each.value
  }
}

# ECR lifecycle policies
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = toset(var.ecr_repositories)
  repository = aws_ecr_repository.repos[each.value].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 tagged images"
        selection = {
          tagStatus     = "tagged"
          countType     = "imageCountMoreThan"
          countNumber   = 30
          tagPrefixList = ["v"]
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep untagged images for ${var.ecr_retain_untagged_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.ecr_retain_untagged_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}