variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

# Linux node group variables
variable "linux_node_instance_types" {
  description = "Instance types for Linux node group"
  type        = list(string)
  default     = ["m5.large", "m5.xlarge"]
}

variable "linux_node_min_size" {
  description = "Minimum size of Linux node group"
  type        = number
  default     = 1
}

variable "linux_node_max_size" {
  description = "Maximum size of Linux node group"
  type        = number
  default     = 10
}

variable "linux_node_desired_size" {
  description = "Desired size of Linux node group"
  type        = number
  default     = 2
}

# Windows node group variables
variable "windows_node_instance_types" {
  description = "Instance types for Windows node group (optimized for Sitecore workloads)"
  type        = list(string)
  default     = ["m5.2xlarge"]
}

variable "windows_node_min_size" {
  description = "Minimum size of Windows node group"
  type        = number
  default     = 1
}

variable "windows_node_max_size" {
  description = "Maximum size of Windows node group"
  type        = number
  default     = 6
}

variable "windows_node_desired_size" {
  description = "Desired size of Windows node group"
  type        = number
  default     = 2
}

# ECR lifecycle retention settings
variable "ecr_retain_untagged_days" {
  description = "Number of days to retain untagged ECR images"
  type        = number
  default     = 7
}

variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type        = list(string)
  default     = ["api", "web", "worker", "cm", "cd"]
}

# DNS/TLS controller variables
variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Enable cert-manager for TLS certificate management"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable external-dns for Route 53 DNS management"
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate registration"
  type        = string
  default     = "admin@cluckn-bell.com"
}

# Argo CD variables
variable "enable_argocd" {
  description = "Enable Argo CD"
  type        = bool
  default     = true
}

variable "argocd_version" {
  description = "Version of Argo CD Helm chart"
  type        = string
  default     = "7.6.12"
}

variable "argocd_auto_sync" {
  description = "Enable auto sync for Argo CD applications"
  type        = bool
  default     = false
}

# VPC configuration variables
variable "create_vpc_if_missing" {
  description = "Create VPC if one with the expected name does not exist"
  type        = bool
  default     = true
}

variable "vpc_name" {
  description = "Override VPC name for discovery. If null, defaults to '{environment}-vpc'"
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "CIDR block for VPC when creating a new one"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets when creating a new VPC. If empty, will auto-calculate"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets when creating a new VPC. If empty, will auto-calculate"
  type        = list(string)
  default     = []
}