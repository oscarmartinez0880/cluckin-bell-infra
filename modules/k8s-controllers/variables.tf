variable "cluster_name" {
  description = "Name of the EKS cluster"
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
  description = "Domain filter for external-dns (e.g., cluckin-bell.com)"
  type        = string
}