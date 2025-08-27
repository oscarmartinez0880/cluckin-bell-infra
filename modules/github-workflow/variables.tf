variable "manage_github_workflow" {
  description = "Whether to manage the GitHub workflow file via Terraform"
  type        = bool
  default     = false
}

variable "repository_name" {
  description = "GitHub repository name (e.g., 'cluckin-bell')"
  type        = string
  default     = "cluckin-bell"
}

variable "codecommit_mirror_role_arn" {
  description = "ARN of the IAM role for CodeCommit mirroring"
  type        = string
}

variable "commit_author" {
  description = "Author name for GitHub commits"
  type        = string
  default     = "Terraform"
}

variable "commit_email" {
  description = "Author email for GitHub commits"
  type        = string
  default     = "terraform@cluckin-bell.com"
}