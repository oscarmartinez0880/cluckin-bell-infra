# SES SMTP Deployment Quick Reference

This is a quick reference guide for deploying the SES SMTP infrastructure for Alertmanager email delivery.

## Prerequisites

- Terraform >= 1.13.1
- AWS CLI configured with profiles:
  - `cluckin-bell-prod` for production account (346746763840)
  - `cluckin-bell-qa` for nonprod account (264765154707)
- AWS SSO login or credentials configured

## Deployment Steps

### 1. Deploy DNS Infrastructure (if not already deployed)

```bash
cd terraform/dns
terraform init
terraform plan
terraform apply
```

This creates:
- Apex zone: `cluckn-bell.com` (prod account)
- Subzones: `dev.cluckn-bell.com`, `qa.cluckn-bell.com` (devqa account)
- NS delegation records

**Important**: Note the `prod_apex_zone_id` output value for the next step.

### 2. Deploy Production SES and Secrets

```bash
cd terraform/clusters/prod

# Initialize if not already done
terraform init

# Plan with zone ID from DNS stack
terraform plan -var="prod_apex_zone_id=<ZONE_ID_FROM_DNS>"

# Apply
terraform apply -var="prod_apex_zone_id=<ZONE_ID_FROM_DNS>"
```

This creates:
- SES domain identity for `cluckn-bell.com`
- Route53 verification TXT record
- Route53 DKIM CNAME records (3 records)
- Secrets Manager secret: `/alertmanager/smtp` (with empty credentials)

### 3. Deploy Nonprod Secrets

```bash
cd terraform/clusters/devqa

# Initialize if not already done
terraform init

# Plan and apply
terraform plan
terraform apply
```

This creates:
- Secrets Manager secret: `/alertmanager/smtp` (nonprod account)

### 4. Wait for DNS Propagation

DNS propagation typically takes a few minutes but can take up to 48 hours.

Check verification status:
```bash
# Check DNS records
dig TXT _amazonses.cluckn-bell.com
dig CNAME <dkim-token>._domainkey.cluckn-bell.com

# Check SES verification status
aws ses get-identity-verification-attributes \
  --identities cluckn-bell.com \
  --region us-east-1 \
  --profile cluckin-bell-prod
```

### 5. Create and Store SMTP Credentials

**IMPORTANT**: This is a manual step that must be completed after Terraform deployment.

See [SES_SMTP_SETUP.md](SES_SMTP_SETUP.md) for detailed instructions on:
1. Creating SES SMTP credentials via AWS Console or CLI
2. Storing credentials in Secrets Manager
3. Configuring ExternalSecrets in your GitOps repository
4. Configuring Alertmanager

## Quick Command Reference

### Check Terraform Outputs

```bash
# Production
cd terraform/clusters/prod
terraform output ses_domain_identity_arn
terraform output ses_smtp_smarthost
terraform output alertmanager_smtp_secret_arn

# Nonprod
cd terraform/clusters/devqa
terraform output alertmanager_smtp_secret_arn_nonprod
```

### Verify SES Status

```bash
# Check domain verification status
aws ses get-identity-verification-attributes \
  --identities cluckn-bell.com \
  --region us-east-1 \
  --profile cluckin-bell-prod

# Check DKIM status
aws ses get-identity-dkim-attributes \
  --identities cluckn-bell.com \
  --region us-east-1 \
  --profile cluckin-bell-prod

# Check sending quota
aws ses get-send-quota \
  --region us-east-1 \
  --profile cluckin-bell-prod
```

### Update Secrets Manager (After Creating SMTP Credentials)

```bash
# Production
aws secretsmanager update-secret \
  --secret-id /alertmanager/smtp \
  --region us-east-1 \
  --profile cluckin-bell-prod \
  --secret-string '{
    "smtp_smarthost": "email-smtp.us-east-1.amazonaws.com:587",
    "smtp_from": "alerts@cluckn-bell.com",
    "smtp_username": "YOUR_SMTP_USERNAME",
    "smtp_password": "YOUR_SMTP_PASSWORD",
    "smtp_require_tls": "true"
  }'

# Nonprod
aws secretsmanager update-secret \
  --secret-id /alertmanager/smtp \
  --region us-east-1 \
  --profile cluckin-bell-qa \
  --secret-string '{
    "smtp_smarthost": "email-smtp.us-east-1.amazonaws.com:587",
    "smtp_from": "alerts@cluckn-bell.com",
    "smtp_username": "YOUR_SMTP_USERNAME_NONPROD",
    "smtp_password": "YOUR_SMTP_PASSWORD_NONPROD",
    "smtp_require_tls": "true"
  }'
```

## Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│ Production Account (346746763840)                   │
├─────────────────────────────────────────────────────┤
│ • SES Domain Identity: cluckn-bell.com             │
│ • DKIM: Enabled (3 CNAME records)                  │
│ • Route53 Zone: cluckn-bell.com                    │
│   - _amazonses TXT (verification)                  │
│   - <token>._domainkey CNAME (DKIM x3)            │
│ • Secrets Manager: /alertmanager/smtp              │
│ • SMTP Endpoint: email-smtp.us-east-1.amazonaws... │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Nonprod Account (264765154707)                     │
├─────────────────────────────────────────────────────┤
│ • Secrets Manager: /alertmanager/smtp              │
│ • Uses prod SES identity (same sender)             │
│ • SMTP Endpoint: email-smtp.us-east-1.amazonaws... │
└─────────────────────────────────────────────────────┘

         ▼
┌─────────────────────────────────────────────────────┐
│ GitOps (cluckin-bell repository)                    │
├─────────────────────────────────────────────────────┤
│ • ExternalSecret: Mounts from Secrets Manager      │
│ • Alertmanager: Configured with SMTP settings      │
│ • Sends alerts via SES SMTP                        │
└─────────────────────────────────────────────────────┘
```

## Troubleshooting

### SES Sandbox Mode

If the nonprod account is in SES sandbox mode:
- Recipient email addresses must be verified
- Request production access: AWS Console → SES → Account Dashboard → Request Production Access

### DNS Verification Stuck

If domain verification is taking too long:
1. Check nameservers are correctly configured at your domain registrar
2. Verify DNS records exist: `dig TXT _amazonses.cluckn-bell.com`
3. Wait up to 48 hours for DNS propagation

### Secrets Manager Access Issues

If ExternalSecrets cannot read from Secrets Manager:
1. Verify IRSA role has `secretsmanager:GetSecretValue` permission
2. Check the secret ARN is correct in ExternalSecret spec
3. Verify the secret exists: `aws secretsmanager describe-secret --secret-id /alertmanager/smtp`

## Next Steps

1. ✅ Deploy Terraform infrastructure (this guide)
2. 📝 Create SES SMTP credentials (see [SES_SMTP_SETUP.md](SES_SMTP_SETUP.md))
3. 🔐 Store credentials in Secrets Manager
4. 🔄 Configure ExternalSecrets in GitOps repository
5. 📧 Configure Alertmanager email receivers
6. ✉️ Test email delivery

## Related Documentation

- [SES SMTP Setup Guide](SES_SMTP_SETUP.md) - Complete setup instructions
- [Terraform DNS Module](../terraform/dns/README.md) - DNS infrastructure
- [ExternalSecrets Documentation](https://external-secrets.io/)
