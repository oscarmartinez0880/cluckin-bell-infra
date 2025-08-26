# Core infrastructure variables
variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be one of: dev, qa, prod."
  }
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cluckin-bell"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "cluckin-bell"
    ManagedBy = "terraform"
  }
}

# AWS-specific variables for CI runners
variable "aws_region" {
  description = "AWS region for CI runners infrastructure"
  type        = string
  default     = "us-east-1"
}

# CI Runners Configuration
variable "enable_ci_runners" {
  description = "Enable Windows GitHub Actions CI runners"
  type        = bool
  default     = false
}

variable "ci_runners_github_app_id" {
  description = "GitHub App ID for CI runner authentication"
  type        = string
  default     = ""
}

variable "ci_runners_github_app_installation_id" {
  description = "GitHub App Installation ID for CI runners"
  type        = string
  default     = ""
}

variable "ci_runners_github_app_private_key_ssm_parameter" {
  description = "SSM Parameter name containing the GitHub App private key"
  type        = string
  default     = "/github/app/private-key"
}

variable "ci_runners_github_repository_allowlist" {
  description = "List of GitHub repositories allowed to use the CI runners"
  type        = list(string)
  default     = []
}

variable "ci_runners_instance_type" {
  description = "EC2 instance type for CI runners"
  type        = string
  default     = "m5.2xlarge"
}

variable "ci_runners_max_size" {
  description = "Maximum number of CI runner instances"
  type        = number
  default     = 10
}

# Azure-specific variables
# variable "azure_location" {
#   description = "Azure location"
#   type        = string
#   default     = "East US"
# }

# GCP-specific variables
# variable "gcp_project_id" {
#   description = "GCP project ID"
#   type        = string
# }

# variable "gcp_region" {
#   description = "GCP region"
#   type        = string
#   default     = "us-central1"
# }