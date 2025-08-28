# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# EKS Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

# Route53 Outputs
output "dev_zone_id" {
  description = "Route53 zone ID for dev.cluckn-bell.com"
  value       = module.dev_zone.zone_id
}

output "dev_zone_name_servers" {
  description = "Name servers for dev.cluckn-bell.com"
  value       = module.dev_zone.name_servers
}

output "qa_zone_id" {
  description = "Route53 zone ID for qa.cluckn-bell.com"
  value       = module.qa_zone.zone_id
}

output "qa_zone_name_servers" {
  description = "Name servers for qa.cluckn-bell.com"
  value       = module.qa_zone.name_servers
}

# ACM Outputs
output "dev_certificate_arn" {
  description = "ARN of the dev wildcard certificate"
  value       = module.dev_cert.certificate_arn
}

output "qa_certificate_arn" {
  description = "ARN of the qa wildcard certificate"
  value       = module.qa_cert.certificate_arn
}

# ECR Outputs
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = module.ecr.repository_arn
}

# IRSA Role ARNs
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IRSA role"
  value       = module.irsa_aws_load_balancer_controller.role_arn
}

output "external_dns_dev_role_arn" {
  description = "ARN of the external-dns dev IRSA role"
  value       = module.irsa_external_dns_dev.role_arn
}

output "external_dns_qa_role_arn" {
  description = "ARN of the external-dns qa IRSA role"
  value       = module.irsa_external_dns_qa.role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the cluster autoscaler IRSA role"
  value       = module.irsa_cluster_autoscaler.role_arn
}

output "aws_for_fluent_bit_role_arn" {
  description = "ARN of the aws-for-fluent-bit IRSA role"
  value       = module.irsa_aws_for_fluent_bit.role_arn
}

output "external_secrets_role_arn" {
  description = "ARN of the external-secrets IRSA role"
  value       = module.irsa_external_secrets.role_arn
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool"
  value       = module.cognito.user_pool_arn
}

output "cognito_user_pool_domain" {
  description = "Domain of the Cognito user pool"
  value       = module.cognito.user_pool_domain
}

output "cognito_client_ids" {
  description = "Cognito client IDs"
  value       = module.cognito.client_ids
}

# GitHub OIDC Outputs
output "github_ecr_push_role_arn" {
  description = "ARN of the GitHub Actions ECR push role"
  value       = module.github_oidc.role_arn
}

# Secrets Manager Outputs
output "secret_arns" {
  description = "ARNs of the created secrets"
  value       = module.secrets.secret_arns
}

output "secret_names" {
  description = "Names of the created secrets"
  value       = module.secrets.secret_names
}