# SES SMTP Setup for Alertmanager Email Delivery

This document provides step-by-step instructions for configuring Amazon SES SMTP credentials for Alertmanager email delivery in both nonprod and prod environments.

## Overview

The infrastructure provisions:
- **SES Domain Identity**: Verified domain identity for `cluckn-bell.com` in prod account (346746763840)
- **DKIM Configuration**: Automatic DKIM signing for enhanced email deliverability
- **Route53 DNS Records**: Verification TXT and DKIM CNAME records in the prod hosted zone
- **Secrets Manager**: `/alertmanager/smtp` secrets in both nonprod (264765154707) and prod accounts

## Architecture

- **Production Account (346746763840)**:
  - SES domain identity for `cluckn-bell.com`
  - Route53 DNS records for verification and DKIM
  - Secrets Manager secret: `/alertmanager/smtp`

- **Nonprod Account (264765154707)**:
  - Reuses prod SES identity (same sender domain)
  - Secrets Manager secret: `/alertmanager/smtp`

Both environments send from `alerts@cluckn-bell.com` using the verified SES domain identity in prod.

## Prerequisites

1. Terraform infrastructure deployed (terraform/clusters/prod and terraform/clusters/devqa)
2. AWS CLI configured with appropriate profiles:
   - `cluckin-bell-prod` for production account
   - `cluckin-bell-qa` for nonprod account
3. IAM permissions to:
   - Create SES SMTP credentials
   - Update Secrets Manager secrets

## Step 1: Verify DNS Records

After applying Terraform, verify that DNS records have been created:

```bash
# Check verification TXT record
dig TXT _amazonses.cluckn-bell.com

# Check DKIM CNAME records (there should be 3)
dig CNAME <dkim-token-1>._domainkey.cluckn-bell.com
dig CNAME <dkim-token-2>._domainkey.cluckn-bell.com
dig CNAME <dkim-token-3>._domainkey.cluckn-bell.com
```

DNS propagation typically takes a few minutes but can take up to 48 hours.

## Step 2: Verify SES Domain Identity Status

Check the verification status of the SES domain identity:

```bash
# Using AWS CLI with prod profile
aws ses get-identity-verification-attributes \
  --identities cluckn-bell.com \
  --region us-east-1 \
  --profile cluckin-bell-prod
```

The `VerificationStatus` should be `Success` once DNS records are verified.

## Step 3: Create SES SMTP Credentials (Production)

### Option A: AWS Console (Recommended)

1. Sign in to AWS Console with prod account (346746763840)
2. Navigate to **Amazon SES** → **SMTP Settings** (or **Account Dashboard** → **SMTP credentials**)
3. Click **Create SMTP Credentials**
4. Enter an IAM user name: `ses-smtp-alertmanager-prod`
5. Click **Create**
6. **IMPORTANT**: Download and save the credentials securely:
   - SMTP Username (Access Key ID)
   - SMTP Password (Secret Access Key)
   
   **Note**: This is the only time you can view the password!

### Option B: AWS CLI

```bash
# Create IAM user for SMTP
aws iam create-user \
  --user-name ses-smtp-alertmanager-prod \
  --profile cluckin-bell-prod

# Attach SES sending policy
aws iam attach-user-policy \
  --user-name ses-smtp-alertmanager-prod \
  --policy-arn arn:aws:iam::aws:policy/AmazonSesSendingAccess \
  --profile cluckin-bell-prod

# Create access key
aws iam create-access-key \
  --user-name ses-smtp-alertmanager-prod \
  --profile cluckin-bell-prod

# IMPORTANT: Convert Access Key Secret to SMTP Password
# Use the AWS SES SMTP password conversion algorithm
# See: https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html#smtp-credentials-convert
```

**Note**: The AWS Secret Access Key must be converted to an SES SMTP password using the SES-specific algorithm. The console method (Option A) handles this automatically.

## Step 4: Store SMTP Credentials in Secrets Manager (Production)

Update the Secrets Manager secret with the SMTP credentials:

```bash
# Get current secret value
aws secretsmanager get-secret-value \
  --secret-id /alertmanager/smtp \
  --region us-east-1 \
  --profile cluckin-bell-prod

# Update secret with SMTP credentials
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
```

Replace `YOUR_SMTP_USERNAME` and `YOUR_SMTP_PASSWORD` with the credentials from Step 3.

## Step 5: Create SES SMTP Credentials (Nonprod)

Repeat Step 3 for the nonprod account (264765154707):

### AWS Console

1. Sign in to AWS Console with nonprod account (264765154707)
2. Navigate to **Amazon SES** → **SMTP Settings**
3. Click **Create SMTP Credentials**
4. Enter IAM user name: `ses-smtp-alertmanager-nonprod`
5. Click **Create** and save the credentials

### Note on SES Sandbox

If the nonprod account is in SES sandbox mode, you'll need to:
- Verify recipient email addresses, or
- Request production access for the nonprod account

## Step 6: Store SMTP Credentials in Secrets Manager (Nonprod)

Update the Secrets Manager secret in the nonprod account:

```bash
# Update secret with SMTP credentials
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

## Step 7: Configure Alertmanager with ExternalSecrets

In your GitOps repository (cluckin-bell), configure ExternalSecret resources to mount the SMTP credentials:

```yaml
# k8s/prod/alertmanager-smtp-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: alertmanager-smtp
  namespace: monitoring
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: alertmanager-smtp
    creationPolicy: Owner
  data:
    - secretKey: smtp_smarthost
      remoteRef:
        key: /alertmanager/smtp
        property: smtp_smarthost
    - secretKey: smtp_from
      remoteRef:
        key: /alertmanager/smtp
        property: smtp_from
    - secretKey: smtp_username
      remoteRef:
        key: /alertmanager/smtp
        property: smtp_username
    - secretKey: smtp_password
      remoteRef:
        key: /alertmanager/smtp
        property: smtp_password
    - secretKey: smtp_require_tls
      remoteRef:
        key: /alertmanager/smtp
        property: smtp_require_tls
```

## Step 8: Configure Alertmanager to Use SMTP

Update your Alertmanager configuration to use the SMTP credentials:

```yaml
# alertmanager.yml
global:
  smtp_smarthost: {{ .smtp_smarthost }}
  smtp_from: {{ .smtp_from }}
  smtp_auth_username: {{ .smtp_username }}
  smtp_auth_password: {{ .smtp_password }}
  smtp_require_tls: {{ .smtp_require_tls }}

route:
  receiver: email-default
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

receivers:
  - name: email-default
    email_configs:
      - to: 'ops-team@example.com'
        headers:
          Subject: '[{{ .Status }}] {{ .GroupLabels.alertname }}'
```

## Verification

### Test SMTP Connection

You can test SMTP connectivity from a pod in your cluster:

```bash
# Connect to a bastion or pod with AWS CLI
kubectl run -it --rm aws-test --image=amazon/aws-cli --restart=Never -- bash

# Install telnet or use Python to test SMTP
python3 << 'EOF'
import smtplib
import ssl

smtp_host = "email-smtp.us-east-1.amazonaws.com"
smtp_port = 587
smtp_user = "YOUR_SMTP_USERNAME"
smtp_pass = "YOUR_SMTP_PASSWORD"

try:
    server = smtplib.SMTP(smtp_host, smtp_port)
    server.starttls(context=ssl.create_default_context())
    server.login(smtp_user, smtp_pass)
    print("✓ SMTP authentication successful!")
    server.quit()
except Exception as e:
    print(f"✗ SMTP authentication failed: {e}")
EOF
```

### Send Test Email

```bash
# Send test email via SES
aws ses send-email \
  --from alerts@cluckn-bell.com \
  --to your-email@example.com \
  --subject "Test email from SES" \
  --text "This is a test email sent via SES SMTP." \
  --region us-east-1 \
  --profile cluckin-bell-prod
```

## Troubleshooting

### Issue: DNS Records Not Verified

- **Solution**: Wait for DNS propagation (up to 48 hours) or check your domain registrar's DNS settings

### Issue: SMTP Authentication Failed

- **Solution**: 
  - Verify you're using the SMTP password (not the AWS Secret Access Key)
  - Check that the IAM user has `AmazonSesSendingAccess` policy attached
  - Ensure TLS is enabled (port 587 with STARTTLS)

### Issue: Email Not Received

- **Solution**:
  - Check SES sending quota: `aws ses get-send-quota --region us-east-1 --profile cluckin-bell-prod`
  - Verify the domain identity is verified
  - Check CloudWatch Logs for SES delivery failures
  - If in sandbox mode, verify recipient email addresses

### Issue: Secrets Manager Access Denied

- **Solution**: 
  - Verify IAM role/user has permissions to read from Secrets Manager
  - Check that ExternalSecrets operator has correct IRSA role permissions
  - Verify the secret ARN is correct in ExternalSecret spec

## Security Considerations

1. **Credentials Rotation**: Rotate SMTP credentials periodically (every 90 days recommended)
2. **Access Control**: Limit Secrets Manager access to only necessary service accounts
3. **Encryption**: Secrets are encrypted at rest in Secrets Manager by default
4. **TLS**: Always use STARTTLS (port 587) or TLS Wrapper (port 465), never plain SMTP (port 25)
5. **Audit**: Monitor SES sending metrics and CloudWatch Logs for anomalies

## References

- [AWS SES SMTP Credentials](https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [External Secrets Operator](https://external-secrets.io/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)

## Outputs from Terraform

After applying the Terraform configuration, you can retrieve important values:

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

## Next Steps

1. Deploy ExternalSecrets operator if not already deployed
2. Create ExternalSecret resources in your GitOps repository
3. Configure Alertmanager to use the SMTP settings
4. Test email delivery with a test alert
5. Configure alert routing and notification policies as needed
