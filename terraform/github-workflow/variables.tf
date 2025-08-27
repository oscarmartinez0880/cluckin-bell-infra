variable "manage_github_workflow" {
  description = "If true, write the mirror workflow into the app repo"
  type        = bool
  default     = false
}

variable "mirror_role_arn_devqa" {
  description = "IAM Role ARN used by the app repo workflow for dev/qa"
  type        = string
}

variable "mirror_role_arn_prod" {
  description = "IAM Role ARN used by the app repo workflow for prod"
  type        = string
}

variable "app_repo_owner" {
  description = "GitHub owner/org for the app repo"
  type        = string
  default     = "oscarmartinez0880"
}

variable "app_repo_name" {
  description = "GitHub app repo name"
  type        = string
  default     = "cluckn-bell"
}

variable "aws_region" {
  description = "AWS region for CodeCommit"
  type        = string
  default     = "us-east-1"
}

variable "codecommit_repo_name" {
  description = "Name of the CodeCommit repository to mirror into"
  type        = string
  default     = "cluckn-bell"
}