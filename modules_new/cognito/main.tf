terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Cognito User Pool
resource "aws_cognito_user_pool" "main" {
  name = var.user_pool_name

  username_configuration {
    case_sensitive = false
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = false
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  auto_verified_attributes = ["email"]

  tags = var.tags
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.domain_name
  user_pool_id = aws_cognito_user_pool.main.id
}

# Cognito User Pool Clients
resource "aws_cognito_user_pool_client" "clients" {
  for_each = var.clients

  name         = each.key
  user_pool_id = aws_cognito_user_pool.main.id

  callback_urls                        = each.value.callback_urls
  logout_urls                          = each.value.logout_urls
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  generate_secret = true

  depends_on = [aws_cognito_user_pool.main]
}

# Create admin users if specified
resource "aws_cognito_user" "admin_users" {
  for_each = toset(var.admin_user_emails)

  user_pool_id = aws_cognito_user_pool.main.id
  username     = each.value

  attributes = {
    email          = each.value
    email_verified = true
  }

  message_action = "SUPPRESS"
  
  temporary_password = "TempPass123!"

  depends_on = [aws_cognito_user_pool.main]
}