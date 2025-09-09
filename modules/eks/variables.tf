variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# DEPRECATED: Use cluster_version instead
# variable "kubernetes_version" {
#   description = "DEPRECATED: Use cluster_version instead. This variable is no longer used."
#   type        = string
#   default     = "1.28"
# }

variable "cluster_version" {
  description = "Kubernetes/EKS control plane version"
  type        = string
  default     = "1.30"

  validation {
    condition     = can(regex("^1\\.(3[0-9]|[4-9][0-9])$", var.cluster_version)) || can(regex("^[2-9]\\.", var.cluster_version))
    error_message = "cluster_version must be >= 1.30."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS node groups"
  type        = list(string)
}

variable "endpoint_private_access" {
  description = "Enable private access to the EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public access to the EKS cluster endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks for public access to the EKS cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  description = "List of control plane logging types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 7
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group. Valid values: ON_DEMAND, SPOT"
  type        = string
  default     = "ON_DEMAND"
}

variable "instance_types" {
  description = "List of instance types associated with the EKS Node Group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "desired_size" {
  description = "Desired number of nodes in the EKS Node Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of nodes in the EKS Node Group"
  type        = number
  default     = 5
}

variable "min_size" {
  description = "Minimum number of nodes in the EKS Node Group"
  type        = number
  default     = 1
}

variable "max_unavailable" {
  description = "Maximum number of nodes that can be unavailable during update"
  type        = number
  default     = 1
}

variable "vpc_cni_version" {
  description = "Version of the VPC CNI add-on"
  type        = string
  default     = null
}

variable "coredns_version" {
  description = "Version of the CoreDNS add-on"
  type        = string
  default     = null
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy add-on"
  type        = string
  default     = null
}

variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver add-on"
  type        = string
  default     = null
}

variable "enable_github_actions_role" {
  description = "Enable GitHub Actions OIDC role for cluster access"
  type        = bool
  default     = false
}

variable "create_default_node_group" {
  description = "Whether to create the built-in default managed node group"
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name (owner/repo)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}