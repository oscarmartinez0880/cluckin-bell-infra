# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# EKS Outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = var.enable_eks ? module.eks[0].cluster_id : null
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = var.enable_eks ? module.eks[0].cluster_arn : null
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = var.enable_eks ? module.eks[0].cluster_name : null
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = var.enable_eks ? module.eks[0].cluster_endpoint : null
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = var.enable_eks ? module.eks[0].cluster_version : null
}

output "eks_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = var.enable_eks ? module.eks[0].cluster_certificate_authority_data : null
  sensitive   = true
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = var.enable_eks ? module.eks[0].cluster_security_group_id : null
}

output "eks_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = var.enable_eks ? module.eks[0].oidc_issuer_url : null
}

output "eks_oidc_provider_arn" {
  description = "The ARN of the OIDC Identity Provider"
  value       = var.enable_eks ? module.eks[0].oidc_provider_arn : null
}

output "eks_github_actions_role_arn" {
  description = "ARN of the GitHub Actions role for EKS access"
  value       = var.enable_eks ? module.eks[0].github_actions_role_arn : null
}

# ECR Outputs
output "ecr_repository_urls" {
  description = "URLs of the ECR repositories"
  value       = var.enable_ecr ? module.ecr[0].repository_urls : null
}

output "ecr_repository_arns" {
  description = "ARNs of the ECR repositories"
  value       = var.enable_ecr ? module.ecr[0].repository_arns : null
}

# RDS Outputs
output "rds_instance_id" {
  description = "The RDS instance ID"
  value       = var.enable_rds ? module.rds[0].db_instance_id : null
}

output "rds_instance_endpoint" {
  description = "The RDS instance endpoint"
  value       = var.enable_rds ? module.rds[0].db_instance_endpoint : null
}

output "rds_instance_address" {
  description = "The address of the RDS instance"
  value       = var.enable_rds ? module.rds[0].db_instance_address : null
}

output "rds_instance_port" {
  description = "The database port"
  value       = var.enable_rds ? module.rds[0].db_instance_port : null
}

output "rds_instance_name" {
  description = "The database name"
  value       = var.enable_rds ? module.rds[0].db_instance_name : null
}

# ElastiCache Outputs
output "elasticache_redis_primary_endpoint" {
  description = "The address of the primary endpoint for the Redis replication group"
  value       = var.enable_elasticache ? module.elasticache[0].redis_primary_endpoint_address : null
}

output "elasticache_redis_reader_endpoint" {
  description = "The address of the reader endpoint for the Redis replication group"
  value       = var.enable_elasticache ? module.elasticache[0].redis_reader_endpoint_address : null
}

output "elasticache_port" {
  description = "The port number on which the cache accepts connections"
  value       = var.enable_elasticache ? module.elasticache[0].port : null
}

# EFS Outputs
output "efs_file_system_id" {
  description = "The ID that identifies the file system"
  value       = var.enable_efs ? module.efs[0].efs_file_system_id : null
}

output "efs_file_system_dns_name" {
  description = "The DNS name for the filesystem"
  value       = var.enable_efs ? module.efs[0].efs_file_system_dns_name : null
}

output "efs_access_point_ids" {
  description = "The IDs of the EFS access points"
  value       = var.enable_efs ? module.efs[0].efs_access_point_ids : null
}

# IAM Outputs
output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = module.iam.github_oidc_provider_arn
}

output "irsa_role_arns" {
  description = "ARNs of the IRSA roles"
  value       = module.iam.irsa_role_arns
}

# Monitoring Outputs
output "sns_topic_arns" {
  description = "ARNs of the SNS topics"
  value       = module.monitoring.sns_topic_arns
}

# Convenience Outputs for GitHub Actions
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
}

# Kubernetes Configuration (for kubectl)
output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = var.enable_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks[0].cluster_name}" : null
}