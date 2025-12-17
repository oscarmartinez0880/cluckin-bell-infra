variable "terraform_role_name" {
  description = "Name of the IAM role for Terraform deployments via GitHub Actions"
  type        = string
}

variable "eksctl_role_name" {
  description = "Name of the IAM role for eksctl operations via GitHub Actions"
  type        = string
}

variable "ecr_push_role_name" {
  description = "Name of the IAM role for ECR image pushes via GitHub Actions"
  type        = string
}

variable "allowed_repos" {
  description = "List of GitHub repositories allowed to assume these roles (format: 'owner/repo')"
  type        = list(string)
  default     = ["oscarmartinez0880/cluckin-bell-infra"]
}

variable "terraform_policy_arns" {
  description = "List of IAM policy ARNs to attach to the Terraform role"
  type        = list(string)
  default     = []
}

variable "eksctl_policy_arns" {
  description = "List of IAM policy ARNs to attach to the eksctl role"
  type        = list(string)
  default     = []
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs for the ECR push role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
