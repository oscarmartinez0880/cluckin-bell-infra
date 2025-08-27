variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster is deployed"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for platform controllers"
  type        = string
  default     = "kube-system"
}

variable "node_groups" {
  description = "Dependency on EKS node groups"
  type        = any
  default     = null
}

# AWS Load Balancer Controller variables
variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "aws_load_balancer_controller_version" {
  description = "Version of AWS Load Balancer Controller Helm chart"
  type        = string
  default     = "1.8.1"
}

variable "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller"
  type        = string
}

# cert-manager variables
variable "enable_cert_manager" {
  description = "Enable cert-manager"
  type        = bool
  default     = true
}

variable "cert_manager_version" {
  description = "Version of cert-manager Helm chart"
  type        = string
  default     = "v1.15.3"
}

variable "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate registration"
  type        = string
}

# external-dns variables
variable "enable_external_dns" {
  description = "Enable external-dns"
  type        = bool
  default     = true
}

variable "external_dns_version" {
  description = "Version of external-dns Helm chart"
  type        = string
  default     = "1.14.5"
}

variable "external_dns_role_arn" {
  description = "IAM role ARN for external-dns"
  type        = string
}

variable "domain_filter" {
  description = "Domain filter for external-dns (e.g., cluckn-bell.com)"
  type        = string
}

variable "zone_id_filters" {
  description = "List of Route53 zone IDs to manage (for external-dns)"
  type        = list(string)
  default     = []
}

# Argo CD variables
variable "enable_argocd" {
  description = "Enable Argo CD"
  type        = bool
  default     = true
}

variable "argocd_version" {
  description = "Version of Argo CD Helm chart"
  type        = string
  default     = "7.6.12"
}

variable "argocd_auto_sync" {
  description = "Enable auto sync for Argo CD applications"
  type        = bool
  default     = false
}

variable "argocd_repo_server_role_arn" {
  description = "IAM role ARN for Argo CD repo-server to access CodeCommit"
  type        = string
  default     = ""
}

variable "codecommit_repository_url" {
  description = "CodeCommit repository URL for Argo CD"
  type        = string
  default     = ""
}