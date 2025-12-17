terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Health checks for primary endpoints
resource "aws_route53_health_check" "primary" {
  for_each = var.failover_records

  fqdn              = each.value.primary_endpoint
  port              = each.value.health_check_port
  type              = "HTTPS"
  resource_path     = each.value.health_check_path
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name     = "${each.key}-primary"
    Endpoint = each.value.primary_endpoint
  })
}

# Primary (active) DNS records
resource "aws_route53_record" "primary" {
  for_each = var.failover_records

  zone_id = var.hosted_zone_id
  name    = each.value.hostname
  type    = "CNAME"
  ttl     = 60

  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary[each.key].id
  records         = [each.value.primary_endpoint]
}

# Secondary (standby) DNS records
resource "aws_route53_record" "secondary" {
  for_each = var.failover_records

  zone_id = var.hosted_zone_id
  name    = each.value.hostname
  type    = "CNAME"
  ttl     = 60

  set_identifier = "secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }

  records = [each.value.secondary_endpoint]
}
