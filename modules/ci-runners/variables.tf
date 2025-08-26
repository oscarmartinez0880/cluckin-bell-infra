# CI Runners Module Variables

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_count" {
  description = "Number of private subnets to create"
  type        = number
  default     = 2
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for ECR and S3"
  type        = bool
  default     = true
}

# Instance Configuration
variable "instance_type" {
  description = "EC2 instance type for CI runners"
  type        = string
  default     = "m5.2xlarge"
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 150
}

variable "root_volume_type" {
  description = "Type of the root EBS volume"
  type        = string
  default     = "gp3"
}

# Auto Scaling Configuration
variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 0
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 10
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 0
}

# GitHub Configuration
variable "github_app_id" {
  description = "GitHub App ID for runner authentication"
  type        = string
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
}

variable "github_app_private_key_ssm_parameter" {
  description = "SSM Parameter name containing the GitHub App private key"
  type        = string
}

variable "runner_group" {
  description = "GitHub Actions runner group"
  type        = string
  default     = "Default"
}

variable "runner_labels" {
  description = "Labels to assign to the GitHub Actions runners"
  type        = list(string)
  default     = ["self-hosted", "windows", "x64", "windows-containers"]
}

variable "runner_name_prefix" {
  description = "Prefix for runner names"
  type        = string
  default     = "aws-runner"
}

variable "github_repository_allowlist" {
  description = "List of GitHub repositories allowed to use these runners"
  type        = list(string)
  default     = []
}

# Optional Features
variable "enable_ssm_access" {
  description = "Enable AWS Systems Manager access for patching and logs"
  type        = bool
  default     = true
}

variable "enable_webhook" {
  description = "Enable webhook endpoint for autoscaling based on GitHub Actions queue"
  type        = bool
  default     = false
}