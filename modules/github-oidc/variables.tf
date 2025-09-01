variable "role_name" {
  description = "Name of the IAM role for GitHub Actions"
  type        = string
}

variable "github_repo_condition" {
  description = "GitHub repository condition for the trust policy (e.g., 'repo:owner/repo:ref:refs/heads/main')"
  type        = string
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "custom_policy_json" {
  description = "Custom policy JSON document"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}