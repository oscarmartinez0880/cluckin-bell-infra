###############################################################################
# Outputs - Production Cluster
###############################################################################

# Cluster outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

# WAF outputs
output "waf_web_acl_arn" {
  description = "ARN of the WAF WebACL for associating with ALBs"
  value       = module.waf_prod.web_acl_arn
}

output "waf_web_acl_id" {
  description = "ID of the WAF WebACL"
  value       = module.waf_prod.web_acl_id
}

output "waf_web_acl_name" {
  description = "Name of the WAF WebACL"
  value       = module.waf_prod.web_acl_name
}

# VPC outputs for reference
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}