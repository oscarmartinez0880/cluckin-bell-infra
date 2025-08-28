terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.zone_name

  tags = merge(var.tags, {
    Name = var.zone_name
  })
}

# NS records for subdomain delegation (if specified)
resource "aws_route53_record" "subdomain_ns" {
  for_each = var.subdomain_zones

  zone_id = aws_route53_zone.main.zone_id
  name    = each.key
  type    = "NS"
  ttl     = 300
  records = each.value
}