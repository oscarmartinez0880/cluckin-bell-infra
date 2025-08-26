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

# TODO: Uncomment and configure provider-specific variables as needed

# AWS-specific variables
# variable "aws_region" {
#   description = "AWS region"
#   type        = string
#   default     = "us-east-1"
# }

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