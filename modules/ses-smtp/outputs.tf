output "domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.main.arn
}

output "domain_identity_verification_token" {
  description = "Verification token for the SES domain identity"
  value       = aws_ses_domain_identity.main.verification_token
}

output "dkim_tokens" {
  description = "DKIM tokens for the domain"
  value       = aws_ses_domain_dkim.main.dkim_tokens
}

output "smtp_smarthost" {
  description = "SMTP endpoint for the region"
  value       = "email-smtp.${data.aws_region.current.name}.amazonaws.com:587"
}

output "smtp_from_address" {
  description = "Suggested from address for alerts"
  value       = "alerts@${var.domain_name}"
}

# Get current region for SMTP endpoint
data "aws_region" "current" {}
