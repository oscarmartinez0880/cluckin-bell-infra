variable "allowed_repos" {
  description = "List of GitHub repositories allowed to assume roles (e.g., 'repo:owner/repo:*')"
  type        = list(string)
  default = [
    "repo:oscarmartinez0880/cluckin-bell-infra:*",
    "repo:oscarmartinez0880/cluckin-bell:*",
    "repo:oscarmartinez0880/cluckin-bell-app:*",
    "repo:oscarmartinez0880/wingman-api:*"
  ]
}

variable "terraform_role_name" {
  description = "Name of the Terraform role"
  type        = string
  default     = "GitHubActions-Terraform"
}

variable "eksctl_role_name" {
  description = "Name of the eksctl role"
  type        = string
  default     = "GitHubActions-eksctl"
}

variable "ecr_push_role_name" {
  description = "Name of the ECR push role"
  type        = string
  default     = "GitHubActions-ECRPush"
}

variable "terraform_policy_arns" {
  description = "List of managed policy ARNs to attach to Terraform role"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

variable "eksctl_policy_arns" {
  description = "List of managed policy ARNs to attach to eksctl role"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

variable "ecr_push_policy_arns" {
  description = "List of managed policy ARNs to attach to ECR push role"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"]
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
