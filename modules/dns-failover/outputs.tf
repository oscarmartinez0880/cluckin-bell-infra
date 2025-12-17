output "health_check_ids" {
  description = "Map of health check IDs"
  value       = { for k, v in aws_route53_health_check.primary : k => v.id }
}

output "primary_record_names" {
  description = "Map of primary DNS record names"
  value       = { for k, v in aws_route53_record.primary : k => v.name }
}

output "secondary_record_names" {
  description = "Map of secondary DNS record names"
  value       = { for k, v in aws_route53_record.secondary : k => v.name }
}
