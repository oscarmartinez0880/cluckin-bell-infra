variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use (e.g., cluckin-bell-qa, cluckin-bell-prod)"
  type        = string
  default     = ""
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from the EKS cluster (get from: aws eks describe-cluster --name <cluster-name> --query 'cluster.identity.oidc.issuer' --output text)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., nonprod, prod)"
  type        = string
}

variable "controllers_namespace" {
  description = "Kubernetes namespace where controllers will be deployed"
  type        = string
  default     = "kube-system"
}
