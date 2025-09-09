output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = var.create_default_node_group ? aws_eks_node_group.main[0].arn : null
}

output "node_group_status" {
  description = "EKS node group status"
  value       = var.create_default_node_group ? aws_eks_node_group.main[0].status : null
}

output "oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Identity Provider"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions role for EKS access"
  value       = var.enable_github_actions_role ? aws_iam_role.github_actions[0].arn : null
}

output "cluster_log_group_name" {
  description = "Name of the CloudWatch log group for the EKS cluster"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for EKS encryption"
  value       = aws_kms_key.eks.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for EKS encryption"
  value       = aws_kms_key.eks.key_id
}

output "node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = var.create_default_node_group ? aws_iam_role.node_group[0].arn : null
}