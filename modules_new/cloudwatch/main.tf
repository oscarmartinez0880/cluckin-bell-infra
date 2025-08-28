terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "main" {
  for_each = var.log_groups

  name              = each.key
  retention_in_days = var.retention_in_days

  tags = merge(var.tags, {
    Name = each.key
  })
}