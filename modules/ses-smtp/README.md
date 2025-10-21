# SES SMTP Module

This module creates an Amazon SES domain identity with DKIM authentication for SMTP email delivery.

## Features

- Creates SES domain identity
- Enables DKIM signing for enhanced email deliverability
- Optionally creates Route53 DNS records for verification and DKIM
- Provides SMTP endpoint information for Alertmanager configuration

## Usage

```hcl
module "ses_smtp" {
  source = "../../modules/ses-smtp"

  domain_name            = "cluckn-bell.com"
  route53_zone_id        = aws_route53_zone.apex.zone_id
  create_route53_records = true

  tags = {
    Environment = "prod"
    Project     = "cluckin-bell"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| domain_name | The domain name to verify with SES | string | n/a | yes |
| route53_zone_id | Route53 hosted zone ID for DNS records | string | "" | no |
| create_route53_records | Create Route53 DNS records | bool | true | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| domain_identity_arn | ARN of the SES domain identity |
| domain_identity_verification_token | Verification token for the domain |
| dkim_tokens | DKIM tokens for the domain |
| smtp_smarthost | SMTP endpoint for the region |
| smtp_from_address | Suggested from address for alerts |

## DNS Records Created

1. **Verification TXT Record**: `_amazonses.<domain>` - Verifies domain ownership
2. **DKIM CNAME Records** (3): `<token>._domainkey.<domain>` - Enable DKIM signing

## SES SMTP Credentials

**Note**: This module does NOT create SMTP credentials. SMTP credentials must be created manually via:
- AWS Console → SES → SMTP Settings → Create SMTP Credentials
- AWS CLI: Follow the SES SMTP credential generation process

See the main repository documentation for detailed steps on creating and storing SMTP credentials in AWS Secrets Manager.
