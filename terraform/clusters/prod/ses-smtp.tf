###############################################################################
# SES SMTP Configuration for Alertmanager Email Delivery
###############################################################################

# Get the prod apex zone ID from terraform/dns outputs
# This assumes terraform/dns has already been applied
data "terraform_remote_state" "dns" {
  backend = "local"
  config = {
    path = "../../dns/terraform.tfstate"
  }
}

# SES Domain Identity for cluckn-bell.com
module "ses_smtp" {
  source = "../../../modules/ses-smtp"

  providers = { aws = aws.prod }

  domain_name            = "cluckn-bell.com"
  route53_zone_id        = data.terraform_remote_state.dns.outputs.prod_apex_zone_id
  create_route53_records = true

  tags = {
    Project     = "cluckn-bell"
    Environment = "prod"
    Purpose     = "alertmanager-smtp"
  }
}

###############################################################################
# Secrets Manager - SMTP Settings for Alertmanager (Prod)
###############################################################################

# SMTP settings secret in prod account
resource "aws_secretsmanager_secret" "alertmanager_smtp_prod" {
  provider = aws.prod

  name        = "/alertmanager/smtp"
  description = "SMTP settings for Alertmanager email delivery (prod account)"

  tags = {
    Project     = "cluckn-bell"
    Environment = "prod"
    Purpose     = "alertmanager-smtp"
  }
}

# Initial secret version with placeholder values
# smtp_username and smtp_password must be populated manually after creating SES SMTP credentials
resource "aws_secretsmanager_secret_version" "alertmanager_smtp_prod" {
  provider = aws.prod

  secret_id = aws_secretsmanager_secret.alertmanager_smtp_prod.id

  secret_string = jsonencode({
    smtp_smarthost   = module.ses_smtp.smtp_smarthost
    smtp_from        = module.ses_smtp.smtp_from_address
    smtp_username    = "" # To be filled manually after creating SES SMTP credentials
    smtp_password    = "" # To be filled manually after creating SES SMTP credentials
    smtp_require_tls = "true"
  })

  # Use lifecycle to prevent overwriting manually set credentials
  lifecycle {
    ignore_changes = [secret_string]
  }
}
