variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "github_repository_owner" {
  description = "GitHub repository owner"
  type        = string
  default     = "oscarmartinez0880"
}

variable "app_repositories" {
  description = "List of application repositories"
  type        = list(string)
  default     = ["cluckin-bell-app", "wingman-api"]
}

variable "environments" {
  description = "List of environments for this account"
  type        = list(string)
}

variable "cluster_name_prefix" {
  description = "Prefix for EKS cluster names"
  type        = string
  default     = "cb"
}

variable "ecr_lifecycle_keep_count" {
  description = "Number of images to keep in ECR lifecycle policy"
  type        = number
  default     = 50
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "cluckin-bell"
    ManagedBy = "terraform"
  }
}