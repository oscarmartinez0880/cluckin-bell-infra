variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  type        = string
}

variable "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace to install Karpenter"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account for Karpenter"
  type        = string
  default     = "karpenter"
}

variable "chart_version" {
  description = "Version of the Karpenter Helm chart"
  type        = string
  default     = "1.0.1"
}

variable "node_iam_role_name" {
  description = "Name of the IAM role used by Karpenter-provisioned nodes"
  type        = string
}

variable "irq_queue_name" {
  description = "Name of the SQS queue for interruption handling"
  type        = string
  default     = ""
}

variable "enable_pod_identity" {
  description = "Enable EKS Pod Identity instead of IRSA"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
