variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "github_owner" {
  type    = string
  default = "oscarmartinez0880"
}

variable "github_repo" {
  type    = string
  default = "cluckin-bell-app"
}

variable "github_pat_ssm_parameter_name" {
  type        = string
  description = "SSM SecureString param name holding GitHub PAT (e.g., /github/pat/runner)"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}