output "ecr_replication_enabled" {
  description = "Whether ECR replication is enabled"
  value       = var.enable_ecr_replication
}

output "ecr_replication_regions" {
  description = "Regions where ECR images are replicated"
  value       = var.ecr_replication_regions
}

output "secrets_replication_enabled" {
  description = "Whether Secrets Manager replication is enabled"
  value       = var.enable_secrets_replication
}

output "secrets_replication_regions" {
  description = "Regions where secrets are replicated"
  value       = var.secrets_replication_regions
}

output "secret_replicas_config" {
  description = "Map of secret replication configurations for reference"
  value       = local.secret_replicas
}

output "dns_failover_enabled" {
  description = "Whether Route53 DNS failover is enabled"
  value       = var.enable_dns_failover
}

output "primary_health_check_ids" {
  description = "Map of primary health check IDs"
  value       = { for k, v in aws_route53_health_check.primary : k => v.id }
}

output "secondary_health_check_ids" {
  description = "Map of secondary health check IDs"
  value       = { for k, v in aws_route53_health_check.secondary : k => v.id }
}
