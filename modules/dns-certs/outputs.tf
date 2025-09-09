output "public_zone_id" {
  description = "Public Route53 zone ID"
  value       = local.public_zone_id
}

output "private_zone_id" {
  description = "Private Route53 zone ID"
  value       = local.private_zone_id
}

output "public_zone_name_servers" {
  description = "Public zone name servers"
  value = var.public_zone.create ? aws_route53_zone.public[0].name_servers : (
    length(data.aws_route53_zone.existing_public) > 0 ? data.aws_route53_zone.existing_public[0].name_servers : []
  )
}

output "public_zone_name" {
  description = "Public zone name"
  value = var.public_zone.create ? aws_route53_zone.public[0].name : (
    length(data.aws_route53_zone.existing_public) > 0 ? data.aws_route53_zone.existing_public[0].name : var.public_zone.name
  )
}

output "private_zone_name" {
  description = "Private zone name"
  value = var.private_zone.create ? aws_route53_zone.private[0].name : (
    length(data.aws_route53_zone.existing_private) > 0 ? data.aws_route53_zone.existing_private[0].name : var.private_zone.name
  )
}

output "certificate_arns" {
  description = "Map of certificate ARNs"
  value = {
    for cert_key, cert in aws_acm_certificate_validation.main :
    cert_key => cert.certificate_arn
  }
}

output "certificate_domains" {
  description = "Map of certificate domain names"
  value = {
    for cert_key, cert in aws_acm_certificate.main :
    cert_key => cert.domain_name
  }
}