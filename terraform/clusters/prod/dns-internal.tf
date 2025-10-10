# Private Route53 hosted zone for internal services in Prod
resource "aws_route53_zone" "internal_prod" {
  name = "internal.cluckn-bell.com"

  vpc {
    vpc_id = module.vpc.vpc_id
  }

  comment = "Private hosted zone for internal services in Prod"

  tags = {
    Name        = "internal.cluckn-bell.com"
    Environment = "prod"
    Project     = "cluckn-bell"
    Type        = "private-internal"
    Purpose     = "internal-cms-access"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Output the internal zone ID for use in ExternalDNS
output "internal_prod_zone_id" {
  description = "Route53 private hosted zone ID for internal.cluckn-bell.com"
  value       = aws_route53_zone.internal_prod.zone_id
}