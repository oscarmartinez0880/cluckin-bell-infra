###############################################################################
# SES SMTP Configuration for Alertmanager Email Delivery (Nonprod)
###############################################################################

# Note: SES domain identity is created in prod account (terraform/clusters/prod)
# Nonprod uses the same sender (alerts@cluckn-bell.com) from prod SES identity
# This is sufficient for nonprod environments sending from the same domain

###############################################################################
# Secrets Manager - SMTP Settings for Alertmanager (Nonprod)
###############################################################################

# SMTP settings secret in nonprod account
resource "aws_secretsmanager_secret" "alertmanager_smtp_nonprod" {
  provider = aws.devqa

  name        = "/alertmanager/smtp"
  description = "SMTP settings for Alertmanager email delivery (nonprod account)"

  tags = {
    Project     = "cluckn-bell"
    Environment = "nonprod"
    Purpose     = "alertmanager-smtp"
  }
}

# Initial secret version with placeholder values
# smtp_username and smtp_password must be populated manually after creating SES SMTP credentials
resource "aws_secretsmanager_secret_version" "alertmanager_smtp_nonprod" {
  provider = aws.devqa

  secret_id = aws_secretsmanager_secret.alertmanager_smtp_nonprod.id

  secret_string = jsonencode({
    smtp_smarthost   = "email-smtp.us-east-1.amazonaws.com:587"
    smtp_from        = "alerts@cluckn-bell.com"
    smtp_username    = "" # To be filled manually after creating SES SMTP credentials
    smtp_password    = "" # To be filled manually after creating SES SMTP credentials
    smtp_require_tls = "true"
  })

  # Use lifecycle to prevent overwriting manually set credentials
  lifecycle {
    ignore_changes = [secret_string]
  }
}
