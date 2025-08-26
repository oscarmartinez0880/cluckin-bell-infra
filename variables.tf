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