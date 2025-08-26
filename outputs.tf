output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

# Linux node group outputs
output "linux_node_group_id" {
  description = "EKS Linux node group ID"
  value       = module.eks.eks_managed_node_groups["linux"].node_group_id
}

output "linux_node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Linux Node Group"
  value       = module.eks.eks_managed_node_groups["linux"].node_group_arn
}

output "linux_node_group_role_arn" {
  description = "Amazon Resource Name (ARN) of the IAM role for Linux node group"
  value       = module.eks.eks_managed_node_groups["linux"].iam_role_arn
}

# Windows node group outputs
output "windows_node_group_id" {
  description = "EKS Windows node group ID"
  value       = module.eks.eks_managed_node_groups["windows"].node_group_id
}

output "windows_node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Windows Node Group"
  value       = module.eks.eks_managed_node_groups["windows"].node_group_arn
}

output "windows_node_group_role_arn" {
  description = "Amazon Resource Name (ARN) of the IAM role for Windows node group"
  value       = module.eks.eks_managed_node_groups["windows"].iam_role_arn
}

# Cluster access
output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_token" {
  description = "Token to use to authenticate with the cluster"
  value       = data.aws_eks_cluster_auth.cluster.token
  sensitive   = true
}

# KMS key
output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key for EKS encryption"
  value       = aws_kms_key.eks.arn
}

# Data source for cluster auth
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# ECR outputs
output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value = {
    for repo in var.ecr_repositories : repo => aws_ecr_repository.repos[repo].repository_url
  }
}

output "ecr_repository_arns" {
  description = "Map of ECR repository ARNs"
  value = {
    for repo in var.ecr_repositories : repo => aws_ecr_repository.repos[repo].arn
  }
}