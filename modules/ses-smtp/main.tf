terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# SES Domain Identity
resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

# Enable DKIM for the domain
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# Route53 verification TXT record for SES domain identity
resource "aws_route53_record" "ses_verification" {
  count = var.create_route53_records && var.route53_zone_id != "" ? 1 : 0

  zone_id = var.route53_zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.main.verification_token]
}

# Route53 DKIM CNAME records (3 records for DKIM)
resource "aws_route53_record" "dkim_records" {
  count = var.create_route53_records && var.route53_zone_id != "" ? 3 : 0

  zone_id = var.route53_zone_id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# Wait for domain verification (optional, commented out by default)
# This can take time, so we'll document the manual verification step instead
# resource "aws_ses_domain_identity_verification" "main" {
#   domain = aws_ses_domain_identity.main.id
#   depends_on = [aws_route53_record.ses_verification]
# }
