variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where ArgoCD will be deployed"
  type        = string
  default     = "argocd"
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "git_repository" {
  description = "Git repository URL for ArgoCD to sync from (CodeCommit format: codecommit::region://repo-name)"
  type        = string
}

variable "git_path" {
  description = "Path within the git repository for this environment"
  type        = string
}

variable "git_revision" {
  description = "Git revision (branch/tag/commit) to sync from"
  type        = string
  default     = "main"
}

variable "argocd_version" {
  description = "Version of ArgoCD Helm chart to deploy"
  type        = string
  default     = "5.51.6"
}

variable "node_groups" {
  description = "EKS node groups dependency"
  type        = any
  default     = {}
}

variable "argocd_repo_server_role_arn" {
  description = "IAM role ARN for Argo CD repo-server to access CodeCommit"
  type        = string
  default     = ""
}