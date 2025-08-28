variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "cluckin-bell"
}

variable "create_github_oidc_provider" {
  description = "Whether to create a new GitHub OIDC provider. Set to false if one already exists."
  type        = bool
  default     = true
}