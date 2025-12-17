terraform {
  required_version = ">= 1.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ECR Cross-Region Replication Configuration
resource "aws_ecr_replication_configuration" "replication" {
  count = var.enable_ecr_replication && length(var.ecr_replication_regions) > 0 ? 1 : 0

  replication_configuration {
    dynamic "rule" {
      for_each = var.ecr_replication_regions
      content {
        destination {
          region      = rule.value
          registry_id = data.aws_caller_identity.current.account_id
        }
      }
    }
  }
}

# Secrets Manager Replication
# Note: Secrets Manager replication is configured on the primary secret resource
# This module outputs information about replication configuration
# Actual replication must be configured on aws_secretsmanager_secret resource
# using the replica block. See module README for usage.

locals {
  # Create a map of secret replication configurations for output
  # Using a unique delimiter to avoid conflicts in key generation
  secret_replicas = var.enable_secrets_replication && length(var.secrets_replication_regions) > 0 ? {
    for pair in flatten([
      for secret_id in var.secret_ids : [
        for region in var.secrets_replication_regions : {
          key       = "${secret_id}::${region}" # Using :: as delimiter to avoid conflicts
          secret_id = secret_id
          region    = region
        }
      ]
    ]) : pair.key => pair
  } : {}
}

# Route53 Health Checks for DNS Failover
resource "aws_route53_health_check" "primary" {
  for_each = var.enable_dns_failover ? var.failover_records : {}

  fqdn              = each.value.primary_endpoint
  port              = 443
  type              = "HTTPS"
  resource_path     = each.value.health_check_path
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "${each.key}-primary"
    Type = "primary"
  })
}

resource "aws_route53_health_check" "secondary" {
  for_each = var.enable_dns_failover ? var.failover_records : {}

  fqdn              = each.value.secondary_endpoint
  port              = 443
  type              = "HTTPS"
  resource_path     = each.value.health_check_path
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, {
    Name = "${each.key}-secondary"
    Type = "secondary"
  })
}

# Route53 DNS Failover Records
resource "aws_route53_record" "primary" {
  for_each = var.enable_dns_failover ? var.failover_records : {}

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  set_identifier  = "${each.key}-primary"
  health_check_id = aws_route53_health_check.primary[each.key].id

  failover_routing_policy {
    type = "PRIMARY"
  }

  records = [each.value.primary_endpoint]
}

resource "aws_route53_record" "secondary" {
  for_each = var.enable_dns_failover ? var.failover_records : {}

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  set_identifier  = "${each.key}-secondary"
  health_check_id = aws_route53_health_check.secondary[each.key].id

  failover_routing_policy {
    type = "SECONDARY"
  }

  records = [each.value.secondary_endpoint]
}
