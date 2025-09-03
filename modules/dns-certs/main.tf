terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_route53_zone" "existing_public" {
  count        = var.public_zone.create ? 0 : 1
  name         = var.public_zone.name
  private_zone = false
}

data "aws_route53_zone" "existing_private" {
  count        = var.private_zone.create ? 0 : (var.existing_private_zone_id != "" ? 0 : 1)
  name         = var.private_zone.name
  private_zone = true
}

# Public Route53 Zone (create or reference existing)
resource "aws_route53_zone" "public" {
  count = var.public_zone.create ? 1 : 0
  name  = var.public_zone.name

  tags = merge(var.tags, {
    Name = var.public_zone.name
    Type = "public"
  })
}

# Private Route53 Zone (create or reference existing)
resource "aws_route53_zone" "private" {
  count = var.private_zone.create ? 1 : 0
  name  = var.private_zone.name

  vpc {
    vpc_id = var.private_zone.vpc_id
  }

  tags = merge(var.tags, {
    Name = var.private_zone.name
    Type = "private"
  })
}

# Zone ID locals and certificate validation records
locals {
  # Zone ID locals - select IDs in this order: created resource → provided ID (for private) → data lookup
  public_zone_id = var.public_zone.create ? aws_route53_zone.public[0].zone_id : data.aws_route53_zone.existing_public[0].zone_id
  
  private_zone_id = var.private_zone.create ? aws_route53_zone.private[0].zone_id : (
    var.existing_private_zone_id != "" ? var.existing_private_zone_id : (
      var.private_zone.zone_id != null ? var.private_zone.zone_id : data.aws_route53_zone.existing_private[0].zone_id
    )
  )

  # Flatten certificate validation options
  certificate_validation_records = merge([
    for cert_key, cert in var.certificates : {
      for dvo in aws_acm_certificate.main[cert_key].domain_validation_options :
      "${cert_key}-${dvo.domain_name}" => {
        cert_key = cert_key
        name     = dvo.resource_record_name
        record   = dvo.resource_record_value
        type     = dvo.resource_record_type
        zone_id  = cert.use_private_zone ? local.private_zone_id : local.public_zone_id
      }
    }
  ]...)
}

# Subdomain delegation records in public zone
resource "aws_route53_record" "subdomain_ns" {
  for_each = var.subdomain_zones

  zone_id = local.public_zone_id
  name    = each.key
  type    = "NS"
  ttl     = 300
  records = each.value
}

# ACM Certificates
resource "aws_acm_certificate" "main" {
  for_each = var.certificates

  domain_name       = each.value.domain_name
  validation_method = "DNS"

  subject_alternative_names = each.value.subject_alternative_names

  lifecycle {
    create_before_destroy = true
  }

  # Sanitize Name tag to avoid invalid '*' in wildcard domains
  tags = merge(var.tags, {
    Name = replace(each.value.domain_name, "*.", "wildcard-")
  })
}

resource "aws_route53_record" "validation" {
  for_each = local.certificate_validation_records

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "main" {
  for_each = var.certificates

  certificate_arn = aws_acm_certificate.main[each.key].arn
  validation_record_fqdns = [
    for record_key, record in aws_route53_record.validation :
    record.fqdn
    if local.certificate_validation_records[record_key].cert_key == each.key
  ]

  timeouts {
    create = "20m"
  }
}