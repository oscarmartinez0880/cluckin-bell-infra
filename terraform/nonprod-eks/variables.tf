variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "cluckin-bell-qa"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"

  validation {
    condition     = can(regex("^1\\.(30|3[1-9]|[4-9][0-9])$", var.cluster_version)) || can(regex("^[2-9]\\.", var.cluster_version))
    error_message = "cluster_version must be >= 1.30."
  }
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (tagged with kubernetes.io/role/elb)"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs (tagged with kubernetes.io/role/internal-elb)"
  type        = list(string)
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    Project    = "cluckin-bell"
    ManagedBy  = "Terraform"
    CostCenter = "platform"
  }
}