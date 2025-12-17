terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Generate random passwords for each secret field that needs one
resource "random_password" "generated" {
  for_each = {
    for secret_key, secret_config in var.secrets :
    secret_key => secret_config
    if length(secret_config.generated_values) > 0
  }

  length  = 16
  special = true
}

# Generate individual passwords for fields that need unique values
resource "random_password" "field_passwords" {
  for_each = {
    for combo in flatten([
      for secret_key, secret_config in var.secrets : [
        for field_key, field_config in secret_config.generated_values : {
          secret_key = secret_key
          field_key  = field_key
          key        = "${secret_key}:${field_key}"
        }
      ]
    ]) : combo.key => combo
  }

  length  = 16
  special = true
}

# Create Secrets Manager secrets
resource "aws_secretsmanager_secret" "main" {
  for_each = var.secrets

  name        = each.key
  description = each.value.description

  # Configure replication if enabled
  dynamic "replica" {
    for_each = var.enable_replication ? var.replication_regions : []
    content {
      region = replica.value
    }
  }

  tags = merge(var.tags, {
    Name = each.key
  })
}

# Store secret values
resource "aws_secretsmanager_secret_version" "main" {
  for_each = var.secrets

  secret_id = aws_secretsmanager_secret.main[each.key].id

  secret_string = jsonencode(
    merge(
      each.value.static_values,
      {
        for field_key, field_config in each.value.generated_values :
        field_key => random_password.field_passwords["${each.key}:${field_key}"].result
      }
    )
  )
}