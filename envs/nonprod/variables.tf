# Variables used by envs/nonprod when loading nonprod.tfvars via -var-file
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile (informational)"
  type        = string
  default     = ""
}

variable "create_vpc_if_missing" {
  type    = bool
  default = true
}

variable "existing_vpc_name" {
  type    = string
  default = ""
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = []
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = []
}

variable "manage_route53" {
  type    = bool
  default = true
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
  validation {
    condition     = can(regex("^1\\.(3[3-9]|[4-9][0-9])(\\..*)?$", var.kubernetes_version))
    error_message = "Kubernetes version must be 1.33 or higher."
  }
}

variable "enable_aws_load_balancer_controller" {
  type    = bool
  default = true
}

variable "enable_cert_manager" {
  type    = bool
  default = true
}

variable "enable_external_dns" {
  type    = bool
  default = true
}

variable "enable_argocd" {
  type    = bool
  default = true
}

# Node groups (declared for completeness; wire into modules as needed)
variable "linux_node_instance_types" {
  type    = list(string)
  default = ["m5.large", "m5.xlarge"]
}

variable "linux_node_min_size" {
  type    = number
  default = 1
}

variable "linux_node_max_size" {
  type    = number
  default = 5
}

variable "linux_node_desired_size" {
  type    = number
  default = 2
}

variable "windows_node_instance_types" {
  type    = list(string)
  default = ["m5.2xlarge"]
}

variable "windows_node_min_size" {
  type    = number
  default = 1
}

variable "windows_node_max_size" {
  type    = number
  default = 6
}

variable "windows_node_desired_size" {
  type    = number
  default = 2
}

# ECR
variable "ecr_retain_untagged_days" {
  type    = number
  default = 10
}

variable "ecr_repositories" {
  type = list(string)
  default = [
    "cluckin-bell-app",
    "wingman-api",
    "fryer-worker",
    "sauce-gateway",
    "clucker-notify"
  ]
}

# EKS Cluster Configuration - Existing VPC/Subnet Reuse
variable "existing_vpc_id" {
  description = "ID of existing VPC to reuse for EKS cluster"
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "List of existing public subnet IDs to reuse"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of existing private subnet IDs to reuse"
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "Override for EKS cluster name"
  type        = string
  default     = ""
}

variable "cluster_log_retention_days" {
  description = "CloudWatch log group retention in days for EKS cluster"
  type        = number
  default     = 30
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks for public access to the EKS cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Node Group Configuration - Dev Environment
variable "dev_node_group_instance_types" {
  description = "Instance types for dev node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "dev_node_group_sizes" {
  type    = object({ min = number, desired = number, max = number })
  default = { min = 1, desired = 1, max = 2 } # reduced desired/max
}

# Node Group Configuration - QA Environment
variable "qa_node_group_instance_types" {
  description = "Instance types for qa node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "qa_node_group_sizes" {
  type    = object({ min = number, desired = number, max = number })
  default = { min = 1, desired = 1, max = 2 }
}

variable "manage_nat_for_existing_vpc" {
  description = "Create a NAT Gateway and wire private subnets when using an existing VPC"
  type        = bool
  default     = true
}

# Optional: choose which public subnet hosts the NAT (defaults to first public subnet)
variable "nat_public_subnet_id" {
  description = "Public subnet ID to place the NAT Gateway in (if empty, uses first of public_subnet_ids)"
  type        = string
  default     = ""
}

# Feature flags for cost-safe infrastructure management
# These flags gate expensive resources to prevent accidental provisioning
variable "enable_dns" {
  description = "Enable DNS zones and certificates (Route53 costs acceptable per user)"
  type        = bool
  default     = true
}

variable "enable_ecr" {
  description = "Enable ECR repositories (costs incurred when images are stored)"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring, Container Insights, and log groups (requires enable_irsa if agents are used)"
  type        = bool
  default     = false
}

variable "enable_irsa" {
  description = "Enable all IRSA roles (requires EKS cluster with OIDC provider)"
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_irsa || var.enable_dns
    error_message = "enable_dns must be true when enable_irsa is true. IRSA modules (external-dns, cert-manager) require DNS zone IDs."
  }
}

variable "enable_cognito" {
  description = "Enable Cognito user pools (incurs costs)"
  type        = bool
  default     = false
}

variable "enable_github_oidc" {
  description = "Enable GitHub OIDC role for ECR push (requires enable_ecr=true)"
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_github_oidc || var.enable_ecr
    error_message = "enable_ecr must be true when enable_github_oidc is true. GitHub OIDC role requires ECR repository ARNs."
  }
}

variable "enable_secrets" {
  description = "Enable Secrets Manager secrets (incurs costs per secret)"
  type        = bool
  default     = false
}

variable "enable_alerting" {
  description = "Enable alerting infrastructure (SNS topics, CloudWatch alarms)"
  type        = bool
  default     = false
}

# Karpenter Configuration
variable "enable_karpenter" {
  description = "Enable Karpenter for just-in-time node provisioning"
  type        = bool
  default     = false
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.0.1"
}

variable "karpenter_namespace" {
  description = "Kubernetes namespace for Karpenter"
  type        = string
  default     = "kube-system"
}

