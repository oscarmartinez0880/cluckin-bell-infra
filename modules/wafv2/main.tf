terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# IP Set for admin path allow list (if configured)
resource "aws_wafv2_ip_set" "admin_allowlist" {
  count = length(var.admin_ip_allow_cidrs) > 0 ? 1 : 0

  name               = "${var.name_prefix}-admin-allowlist"
  description        = "IP allowlist for admin paths"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"

  addresses = var.admin_ip_allow_cidrs

  tags = var.tags
}

# Main WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.name_prefix}-webacl"
  description = "WAF WebACL for ${var.environment} environment"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # Managed Rule Group: AWS Core Rule Set (CRS)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Managed Rule Group: Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  # Managed Rule Group: Amazon IP Reputation List
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AmazonIpReputationListMetric"
      sampled_requests_enabled   = true
    }
  }

  # Managed Rule Group: SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Managed Rule Group: Linux Operating System
  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "LinuxRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Managed Rule Group: Bot Control (conditionally enabled)
  dynamic "rule" {
    for_each = var.enable_bot_control ? [1] : []
    content {
      name     = "AWSManagedRulesBotControlRuleSet"
      priority = 6

      override_action {
        none {}
      }

      statement {
        managed_rule_group_statement {
          name        = "AWSManagedRulesBotControlRuleSet"
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "BotControlRuleSetMetric"
        sampled_requests_enabled   = true
      }
    }
  }

  # Custom Rule: Rate Limiting for /api paths
  rule {
    name     = "APIRateLimit"
    priority = 10

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string = "/api"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "STARTS_WITH"
          }
        }

        statement {
          rate_based_statement {
            limit              = var.api_rate_limit
            aggregate_key_type = "IP"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "APIRateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # Custom Rule: Size restriction for /api request bodies
  rule {
    name     = "APISizeRestriction"
    priority = 11

    action {
      block {}
    }

    statement {
      and_statement {
        statement {
          byte_match_statement {
            search_string = "/api"
            field_to_match {
              uri_path {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "STARTS_WITH"
          }
        }

        statement {
          size_constraint_statement {
            field_to_match {
              body {}
            }
            comparison_operator = "GT"
            size                = 1048576 # 1MB in bytes
            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "APISizeRestrictionMetric"
      sampled_requests_enabled   = true
    }
  }

  # Custom Rule: Geo blocking (if countries specified)
  dynamic "rule" {
    for_each = length(var.geo_block_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlocking"
      priority = 12

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.geo_block_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockingMetric"
        sampled_requests_enabled   = true
      }
    }
  }

  # Custom Rule: Admin path allowlist (if configured)
  dynamic "rule" {
    for_each = length(var.admin_ip_allow_cidrs) > 0 ? [1] : []
    content {
      name     = "AdminPathAllowlist"
      priority = 13

      action {
        allow {}
      }

      statement {
        and_statement {
          statement {
            byte_match_statement {
              search_string = "/wp-admin"
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
              positional_constraint = "STARTS_WITH"
            }
          }

          statement {
            ip_set_reference_statement {
              arn = aws_wafv2_ip_set.admin_allowlist[0].arn
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "AdminPathAllowlistMetric"
        sampled_requests_enabled   = true
      }
    }
  }

  # CloudWatch metrics and sampling
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-WebACL"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# CloudWatch Log Group for WAF logs (optional)
resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/wafv2/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# WAF logging configuration (optional)
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.enable_logging ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
