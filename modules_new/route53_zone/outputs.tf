output "zone_id" {
  description = "Route53 zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "zone_arn" {
  description = "Route53 zone ARN"
  value       = aws_route53_zone.main.arn
}

output "name_servers" {
  description = "List of name servers for the hosted zone"
  value       = aws_route53_zone.main.name_servers
}

output "zone_name" {
  description = "Name of the hosted zone"
  value       = aws_route53_zone.main.name
}