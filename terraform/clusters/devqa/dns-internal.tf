# Private Route53 hosted zone for internal services in Dev/QA
resource "aws_route53_zone" "internal_dev" {
  name = "internal.dev.cluckn-bell.com"
  
  vpc {
    vpc_id = module.vpc_devqa.vpc_id
  }
  
  comment = "Private hosted zone for internal services in Dev/QA"
  
  tags = {
    Name        = "internal.dev.cluckn-bell.com"
    Environment = "dev-qa"
    Project     = "cluckn-bell"
    Type        = "private-internal"
    Purpose     = "internal-cms-access"
  }
}

# Output the internal zone ID for use in ExternalDNS
output "internal_dev_zone_id" {
  description = "Route53 private hosted zone ID for internal.dev.cluckn-bell.com"
  value       = aws_route53_zone.internal_dev.zone_id
}