# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = local.public_subnet_ids
}

# DNS and Certificate Outputs
output "public_zone_id" {
  description = "Route53 public hosted zone ID for cluckn-bell.com"
  value       = var.enable_dns ? module.dns_certs[0].public_zone_id : ""
}

output "public_zone_name_servers" {
  description = "Name servers for the public hosted zone cluckn-bell.com"
  value       = var.enable_dns ? module.dns_certs[0].public_zone_name_servers : []
}

output "public_zone_name" {
  description = "Public Route53 zone name"
  value       = var.enable_dns ? module.dns_certs[0].public_zone_name : ""
}

output "internal_zone_id" {
  description = "Route53 private hosted zone ID for internal.cluckn-bell.com"
  value       = var.enable_dns ? module.dns_certs[0].private_zone_id : ""
}

output "internal_zone_name" {
  description = "Internal private Route53 zone name"
  value       = var.enable_dns ? module.dns_certs[0].private_zone_name : ""
}

# Legacy output maintained for backward compatibility
output "private_zone_id" {
  description = "Private Route53 zone ID (legacy - use internal_zone_id)"
  value       = var.enable_dns ? module.dns_certs[0].private_zone_id : ""
}

output "certificate_arns" {
  description = "Map of certificate ARNs"
  value       = var.enable_dns ? module.dns_certs[0].certificate_arns : {}
}

# ECR Outputs
output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value       = var.enable_ecr ? module.ecr[0].repository_urls : {}
}

output "ecr_repository_arns" {
  description = "Map of ECR repository ARNs"
  value       = var.enable_ecr ? module.ecr[0].repository_arns : {}
}

# IRSA Role ARNs
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IRSA role"
  value       = var.enable_irsa ? module.irsa_aws_load_balancer_controller[0].role_arn : ""
}

output "external_dns_role_arn" {
  description = "ARN of the external-dns IRSA role"
  value       = var.enable_irsa ? module.irsa_external_dns[0].role_arn : ""
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the cluster autoscaler IRSA role"
  value       = var.enable_irsa ? module.irsa_cluster_autoscaler[0].role_arn : ""
}

output "aws_for_fluent_bit_role_arn" {
  description = "ARN of the aws-for-fluent-bit IRSA role"
  value       = var.enable_irsa ? module.irsa_aws_for_fluent_bit[0].role_arn : ""
}

output "external_secrets_role_arn" {
  description = "ARN of the external-secrets IRSA role"
  value       = var.enable_irsa ? module.irsa_external_secrets[0].role_arn : ""
}

# Cognito Outputs
output "cognito_user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = var.enable_cognito ? module.cognito[0].user_pool_id : ""
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito user pool"
  value       = var.enable_cognito ? module.cognito[0].user_pool_arn : ""
}

output "cognito_user_pool_domain" {
  description = "Domain of the Cognito user pool"
  value       = var.enable_cognito ? module.cognito[0].user_pool_domain : ""
}

output "cognito_client_ids" {
  description = "Cognito client IDs"
  value       = var.enable_cognito ? module.cognito[0].client_ids : {}
}

# GitHub OIDC Outputs
output "github_ecr_push_role_arn" {
  description = "ARN of the GitHub Actions ECR push role"
  value       = (var.enable_github_oidc && var.enable_ecr) ? module.github_oidc[0].role_arn : ""
}

# Secrets Manager Outputs
output "secret_arns" {
  description = "ARNs of the created secrets"
  value       = var.enable_secrets ? module.secrets[0].secret_arns : {}
}

output "secret_names" {
  description = "Names of the created secrets"
  value       = var.enable_secrets ? module.secrets[0].secret_names : []
}

# Cert-Manager IRSA
output "cert_manager_role_arn" {
  description = "ARN of the cert-manager IRSA role"
  value       = var.enable_irsa ? module.irsa_cert_manager[0].role_arn : ""
}

# Alerting Outputs
output "alerting_sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = var.enable_alerting ? module.alerting[0].sns_topic_arn : ""
}

output "alerting_webhook_url" {
  description = "Alertmanager webhook URL"
  value       = var.enable_alerting ? module.alerting[0].webhook_url : ""
}

output "alerting_webhook_secret_name" {
  description = "Name of the Secrets Manager secret containing webhook URL"
  value       = var.enable_alerting ? module.alerting[0].webhook_secret_name : ""
}

# Disaster Recovery Outputs
output "dr_ecr_replication_regions" {
  description = "Regions configured for ECR replication"
  value       = var.enable_ecr_replication && length(var.ecr_replication_regions) > 0 ? module.ecr_replication[0].replication_regions : []
}

output "dr_secrets_replication_regions" {
  description = "Regions configured for Secrets Manager replication"
  value       = var.secrets_replication_regions
}

output "dr_dns_failover_enabled" {
  description = "Whether DNS failover is enabled"
  value       = var.enable_dns_failover
}

output "dr_dns_failover_health_checks" {
  description = "Map of DNS failover health check IDs"
  value       = var.enable_dns && var.enable_dns_failover && length(var.failover_records) > 0 ? module.dns_failover[0].health_check_ids : {}
}