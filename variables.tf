# General Configuration
variable "name" {
  description = "Name to be used on all resources as identifier"
  type        = string
  default     = "cluckin-bell"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform = "true"
    Project   = "cluckin-bell"
  }
}

# VPC Configuration
variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Should be true if you want to provision VPC endpoints"
  type        = bool
  default     = true
}

# IAM Configuration
variable "enable_github_oidc" {
  description = "Whether to create GitHub OIDC provider"
  type        = bool
  default     = true
}

# EKS Configuration
variable "enable_eks" {
  description = "Whether to create EKS cluster"
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "eks_endpoint_private_access" {
  description = "Enable private access to the EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "eks_endpoint_public_access" {
  description = "Enable public access to the EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "List of CIDR blocks for public access to the EKS cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "eks_capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  type        = string
  default     = "ON_DEMAND"
}

variable "eks_instance_types" {
  description = "List of instance types associated with the EKS Node Group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_desired_size" {
  description = "Desired number of nodes in the EKS Node Group"
  type        = number
  default     = 2
}

variable "eks_max_size" {
  description = "Maximum number of nodes in the EKS Node Group"
  type        = number
  default     = 5
}

variable "eks_min_size" {
  description = "Minimum number of nodes in the EKS Node Group"
  type        = number
  default     = 1
}

# GitHub Actions Configuration
variable "enable_github_actions_role" {
  description = "Enable GitHub Actions OIDC role for cluster access"
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repository name (owner/repo)"
  type        = string
  default     = "oscarmartinez0880/cluckin-bell-infra"
}

# ECR Configuration
variable "enable_ecr" {
  description = "Whether to create ECR repositories"
  type        = bool
  default     = true
}

variable "ecr_repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default = [
    "cluckin-bell/web",
    "cluckin-bell/api",
    "cluckin-bell/worker",
    "cluckin-bell/sitecore-cd",
    "cluckin-bell/sitecore-cm"
  ]
}

variable "ecr_image_tag_mutability" {
  description = "The tag mutability setting for the repository"
  type        = string
  default     = "MUTABLE"
}

variable "ecr_scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "ecr_enable_lifecycle_policy" {
  description = "Whether to enable lifecycle policy"
  type        = bool
  default     = true
}

variable "ecr_max_image_count" {
  description = "Maximum number of images to keep"
  type        = number
  default     = 10
}

# RDS Configuration
variable "enable_rds" {
  description = "Whether to create RDS instance"
  type        = bool
  default     = true
}

variable "rds_engine" {
  description = "The database engine"
  type        = string
  default     = "postgres"
}

variable "rds_engine_version" {
  description = "The engine version to use"
  type        = string
  default     = "15.4"
}

variable "rds_instance_class" {
  description = "The instance type of the RDS instance"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "The allocated storage in gigabytes"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Specifies the value for Storage Autoscaling"
  type        = number
  default     = 100
}

variable "rds_db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = "cluckinbell"
}

variable "rds_username" {
  description = "Username for the master DB user"
  type        = string
  default     = "cluckinbell"
}

variable "rds_port" {
  description = "The port on which the DB accepts connections"
  type        = number
  default     = 5432
}

variable "rds_backup_retention_period" {
  description = "The days to retain backups for"
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "The database can't be deleted when this value is set to true"
  type        = bool
  default     = true
}

# ElastiCache Configuration
variable "enable_elasticache" {
  description = "Whether to create ElastiCache cluster"
  type        = bool
  default     = true
}

variable "elasticache_engine" {
  description = "The name of the cache engine to be used"
  type        = string
  default     = "redis"
}

variable "elasticache_engine_version" {
  description = "The version number of the cache engine"
  type        = string
  default     = "7.0"
}

variable "elasticache_node_type" {
  description = "The instance class used"
  type        = string
  default     = "cache.t3.micro"
}

variable "elasticache_num_cache_clusters" {
  description = "The number of cache clusters this replication group will have"
  type        = number
  default     = 2
}

# EFS Configuration
variable "enable_efs" {
  description = "Whether to create EFS file system"
  type        = bool
  default     = true
}

variable "efs_access_points" {
  description = "A map of access point definitions to create"
  type = map(object({
    posix_user = optional(object({
      gid            = number
      uid            = number
      secondary_gids = optional(list(number))
    }))
    root_directory = optional(object({
      path = optional(string)
      creation_info = optional(object({
        owner_gid   = number
        owner_uid   = number
        permissions = string
      }))
    }))
  }))
  default = {
    sitecore = {
      root_directory = {
        path = "/sitecore"
        creation_info = {
          owner_gid   = 1001
          owner_uid   = 1001
          permissions = "755"
        }
      }
    }
  }
}

# Monitoring Configuration
variable "enable_monitoring" {
  description = "Whether to enable monitoring and alerting"
  type        = bool
  default     = true
}

variable "monitoring_email_endpoints" {
  description = "List of email addresses for monitoring alerts"
  type        = list(string)
  default     = null
}