###############################################################################
# Outputs - Dev/QA Shared Cluster
###############################################################################

# Dev/QA Cluster outputs
output "cluster_name_devqa" {
  description = "Name of the shared Dev/QA EKS cluster"
  value       = module.eks_devqa.cluster_name
}

output "cluster_endpoint_devqa" {
  description = "Endpoint for Dev/QA EKS control plane"
  value       = module.eks_devqa.cluster_endpoint
}

output "cluster_oidc_issuer_url_devqa" {
  description = "The URL on the Dev/QA EKS cluster for the OpenID Connect identity provider"
  value       = module.eks_devqa.cluster_oidc_issuer_url
}

output "oidc_provider_arn_devqa" {
  description = "The ARN of the OIDC Provider for IRSA (Dev/QA)"
  value       = module.eks_devqa.oidc_provider_arn
}

# Production Cluster outputs (managed from devqa stack)
output "cluster_name_prod" {
  description = "Name of the Production EKS cluster"
  value       = module.eks_prod.cluster_name
}

output "cluster_endpoint_prod" {
  description = "Endpoint for Production EKS control plane"
  value       = module.eks_prod.cluster_endpoint
}

output "cluster_oidc_issuer_url_prod" {
  description = "The URL on the Production EKS cluster for the OpenID Connect identity provider"
  value       = module.eks_prod.cluster_oidc_issuer_url
}

output "oidc_provider_arn_prod" {
  description = "The ARN of the OIDC Provider for IRSA (Production)"
  value       = module.eks_prod.oidc_provider_arn
}

# WAF outputs - Dev/QA
output "waf_web_acl_arn_devqa" {
  description = "ARN of the WAF WebACL for associating with Dev/QA ALBs"
  value       = module.waf_devqa.web_acl_arn
}

output "waf_web_acl_id_devqa" {
  description = "ID of the WAF WebACL for Dev/QA"
  value       = module.waf_devqa.web_acl_id
}

output "waf_web_acl_name_devqa" {
  description = "Name of the WAF WebACL for Dev/QA"
  value       = module.waf_devqa.web_acl_name
}

# VPC outputs
output "vpc_id_devqa" {
  description = "ID of the Dev/QA VPC"
  value       = module.vpc_devqa.vpc_id
}

output "private_subnet_ids_devqa" {
  description = "IDs of the Dev/QA private subnets"
  value       = module.vpc_devqa.private_subnets
}

output "public_subnet_ids_devqa" {
  description = "IDs of the Dev/QA public subnets"
  value       = module.vpc_devqa.public_subnets
}

output "vpc_id_prod" {
  description = "ID of the Production VPC"
  value       = module.vpc_prod.vpc_id
}

output "private_subnet_ids_prod" {
  description = "IDs of the Production private subnets"
  value       = module.vpc_prod.private_subnets
}

output "public_subnet_ids_prod" {
  description = "IDs of the Production public subnets"
  value       = module.vpc_prod.public_subnets
}

###############################################################################
# SES SMTP Outputs
###############################################################################

output "alertmanager_smtp_secret_arn_nonprod" {
  description = "ARN of the Secrets Manager secret for Alertmanager SMTP settings (nonprod)"
  value       = aws_secretsmanager_secret.alertmanager_smtp_nonprod.arn
}