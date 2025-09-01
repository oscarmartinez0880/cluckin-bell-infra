# Route53 Hosted Zones for cluckn-bell.com

# Public hosted zone for cluckn-bell.com (for ACME challenges and public records)
resource "aws_route53_zone" "public" {
  name = "cluckn-bell.com"

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
  name = "cluckn-bell.com"

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
  value       = aws_route53_zone.public.zone_id
}

output "public_zone_name_servers" {
  description = "Name servers for the public hosted zone"
  value       = aws_route53_zone.public.name_servers
}

output "private_zone_id" {
  description = "Route53 private hosted zone ID for cluckn-bell.com"
  value       = aws_route53_zone.private.zone_id
}