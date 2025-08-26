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