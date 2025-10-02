variable "manage_eks" {
  description = "Whether to manage EKS cluster via Terraform (disabled by default - use eksctl instead)"
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.33"
}

# Linux node group variables
variable "linux_node_instance_types" {
  description = "Instance types for Linux node group"
  type        = list(string)
  default     = ["m5.large", "m5.xlarge"]
}

variable "linux_node_min_size" {
  description = "Minimum size of Linux node group"
  type        = number
  default     = 1
}

variable "linux_node_max_size" {
  description = "Maximum size of Linux node group"
  type        = number
  default     = 8
}

variable "linux_node_desired_size" {
  description = "Desired size of Linux node group"
  type        = number
  default     = 3
}

# DNS/TLS controller variables
variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Enable cert-manager for TLS certificate management"
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Enable external-dns for Route 53 DNS management"
  type        = bool
  default     = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate registration"
  type        = string
  default     = "admin@cluckin-bell.com"
}