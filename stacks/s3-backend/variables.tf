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

variable "state_retention_days" {
  description = "Number of days to retain non-current versions of state files"
  type        = number
  default     = 30
}

variable "enable_access_logging" {
  description = "Enable S3 access logging for the state bucket"
  type        = bool
  default     = false
}