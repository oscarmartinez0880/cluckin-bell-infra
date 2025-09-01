# Route53 Hosted Zones for cluckn-bell.com
locals {
  vpc_id = data.aws_vpc.main.id
}

# Public hosted zone for cluckn-bell.com (for ACME challenges and public records)
resource "aws_route53_zone" "public" {
  count = var.manage_route53 ? 1 : 0
  name  = "cluckn-bell.com"

  tags = {
    Name        = "cluckn-bell.com-public"
    Environment = var.environment
    Project     = "cluckin-bell"
    Stack       = "platform-eks"
    Type        = "public"
  }
}

# Private hosted zone for cluckn-bell.com (for internal services per environment)
resource "aws_route53_zone" "private" {
  count = var.manage_route53 ? 1 : 0
  name  = "cluckn-bell.com"

  vpc {
    vpc_id = local.vpc_id
  }

  tags = {
    Name        = "cluckn-bell.com-private-${var.environment}"
    Environment = var.environment
    Project     = "cluckin-bell"
    Stack       = "platform-eks"
    Type        = "private"
  }
}

# Output the hosted zone information for external-dns and cert-manager
output "public_zone_id" {
  description = "Route53 public hosted zone ID for cluckn-bell.com"
  value       = var.manage_route53 ? aws_route53_zone.public[0].zone_id : null
}

output "public_zone_name_servers" {
  description = "Name servers for the public hosted zone"
  value       = var.manage_route53 ? aws_route53_zone.public[0].name_servers : null
}

output "private_zone_id" {
  description = "Route53 private hosted zone ID for cluckn-bell.com"
  value       = var.manage_route53 ? aws_route53_zone.private[0].zone_id : null
}