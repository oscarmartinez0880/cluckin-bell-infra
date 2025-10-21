# Cert-Manager and Alerting Infrastructure Deployment Guide

This guide covers the deployment of cert-manager IRSA roles and the complete alerting infrastructure for Prometheus Alertmanager.

## Overview

This implementation provisions:

1. **cert-manager IRSA**: IAM roles for cert-manager to perform Route53 DNS01 challenges
2. **Alerting Pipeline**: SNS topics, Lambda webhook processor, API Gateway, and Secrets Manager integration

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform 1.13.1 installed
- Access to both nonprod (264765154707) and prod (346746763840) AWS accounts

## Account Structure

| Environment | Account ID | Cluster | Email/SMS |
|-------------|-----------|---------|-----------|
| **nonprod** (dev + qa) | 264765154707 | cluckn-bell-nonprod | oscar21martinez88@gmail.com / +12298051449 |
| **prod** | 346746763840 | cluckn-bell-prod | oscar21martinez88@gmail.com / +12298051449 |

## Resources Created

### Per Environment

#### Cert-Manager IRSA
- IAM Role: `cluckn-bell-{env}-cert-manager`
- Permissions: Route53 DNS01 challenges on appropriate hosted zones
- Namespace: `cert-manager`
- ServiceAccount: `cert-manager`

#### Alerting
- SNS Topic: `alerts-{env}` (with KMS encryption)
- Email Subscription: oscar21martinez88@gmail.com
- SMS Subscription: +12298051449
- Lambda Function: `alertmanager-webhook-{env}` (Python 3.12)
- API Gateway: HTTP API with `/webhook` endpoint
- Secrets Manager: `alertmanager/webhook-url-{env}`

## Deployment Steps

### 1. Deploy Nonprod Environment

```bash
cd envs/nonprod

# Authenticate to nonprod account
aws sso login --profile cluckin-bell-devqa
export AWS_PROFILE=cluckin-bell-devqa

# Initialize and plan
terraform init
terraform plan -out=nonprod.plan

# Review the plan carefully, then apply
terraform apply nonprod.plan

# Save outputs
terraform output cert_manager_role_arn > /tmp/nonprod-cert-manager-arn.txt
terraform output alerting_webhook_url > /tmp/nonprod-webhook-url.txt
```

**Expected Resources Created:**
- 1 IAM role (cert-manager)
- 1 SNS topic with KMS key
- 2 SNS subscriptions (email + SMS)
- 1 Lambda function
- 1 API Gateway HTTP API
- 1 Secrets Manager secret
- CloudWatch Log Group for Lambda

### 2. Deploy Prod Environment

```bash
cd envs/prod

# Authenticate to prod account
aws sso login --profile cluckin-bell-prod
export AWS_PROFILE=cluckin-bell-prod

# Initialize and plan
terraform init
terraform plan -out=prod.plan

# Review the plan carefully, then apply
terraform apply prod.plan

# Save outputs
terraform output cert_manager_role_arn > /tmp/prod-cert-manager-arn.txt
terraform output alerting_webhook_url > /tmp/prod-webhook-url.txt
```

## Post-Deployment Configuration

### 1. Confirm SNS Email Subscription (Critical!)

**For both nonprod and prod:**

1. Check inbox for `oscar21martinez88@gmail.com`
2. Look for email with subject: "AWS Notification - Subscription Confirmation"
3. Click the "Confirm subscription" link
4. Verify you see the AWS confirmation page

⚠️ **Important**: Email alerts will NOT work until the subscription is confirmed.

SMS alerts to +12298051449 are auto-confirmed and require no action.

### 2. Retrieve Outputs

```bash
# Nonprod
cd envs/nonprod
echo "Cert-Manager Role ARN:"
terraform output cert_manager_role_arn

echo "Webhook URL:"
terraform output alerting_webhook_url

echo "Webhook Secret Name:"
terraform output alerting_webhook_secret_name

# Prod
cd envs/prod
echo "Cert-Manager Role ARN:"
terraform output cert_manager_role_arn

echo "Webhook URL:"
terraform output alerting_webhook_url

echo "Webhook Secret Name:"
terraform output alerting_webhook_secret_name
```

### 3. Configure cert-manager in Kubernetes

Update your cert-manager ServiceAccount with the IRSA role:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager
  namespace: cert-manager
  annotations:
    eks.amazonaws.com/role-arn: <cert_manager_role_arn_from_output>
```

### 4. Configure Alertmanager Webhook

#### Option A: Direct Configuration

```yaml
receivers:
  - name: 'sns-webhook'
    webhook_configs:
      - url: 'https://your-api-gateway-id.execute-api.us-east-1.amazonaws.com/webhook'
        send_resolved: true
```

#### Option B: Using External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: alertmanager-webhook
  namespace: monitoring
spec:
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: alertmanager-webhook-url
  data:
    - secretKey: webhook_url
      remoteRef:
        key: alertmanager/webhook-url-nonprod  # or alertmanager/webhook-url-prod
```

Then reference in Alertmanager config:

```yaml
receivers:
  - name: 'sns-webhook'
    webhook_configs:
      - url: '{{ .webhookUrl }}'
        send_resolved: true
```

## Testing the Alerting Pipeline

### Test the Webhook Manually

```bash
# Get webhook URL
WEBHOOK_URL=$(terraform output -raw alerting_webhook_url)

# Send test alert
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "version": "4",
    "groupKey": "test",
    "status": "firing",
    "alerts": [{
      "status": "firing",
      "labels": {
        "alertname": "TestAlert",
        "severity": "warning",
        "env": "test",
        "instance": "localhost:9090"
      },
      "annotations": {
        "summary": "This is a test alert from Alertmanager webhook"
      },
      "startsAt": "2025-10-21T00:00:00Z"
    }]
  }'
```

Expected response:
```json
{
  "message": "Successfully processed 1 alert(s)",
  "alerts_processed": 1
}
```

Check your email and SMS for the test alert.

### Verify SNS Subscriptions

```bash
# Nonprod
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw alerting_sns_topic_arn) \
  --profile cluckin-bell-devqa

# Prod
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw alerting_sns_topic_arn) \
  --profile cluckin-bell-prod
```

Look for:
- Email subscription with status "Confirmed"
- SMS subscription with status "Confirmed"

### Check Lambda Logs

```bash
# View recent logs
aws logs tail /aws/lambda/alertmanager-webhook-nonprod --follow

# Or for prod
aws logs tail /aws/lambda/alertmanager-webhook-prod --follow
```

## Troubleshooting

### Email Alerts Not Arriving

1. **Check subscription status**:
   ```bash
   aws sns list-subscriptions-by-topic --topic-arn <topic-arn>
   ```
   Status should be "Confirmed", not "PendingConfirmation"

2. **Check spam folder** for confirmation email

3. **Review Lambda logs** for errors:
   ```bash
   aws logs tail /aws/lambda/alertmanager-webhook-{env} --follow
   ```

4. **Test manually** using curl command above

### SMS Alerts Not Arriving

1. **Verify phone format** is E.164 (+12298051449 for US)

2. **Check subscription**:
   ```bash
   aws sns list-subscriptions-by-topic --topic-arn <topic-arn>
   ```

3. **SMS opt-in** may be required in some regions. Check AWS SNS console → Text messaging (SMS) → SMS preferences

### Lambda Errors

1. **Check CloudWatch Logs**:
   ```bash
   aws logs tail /aws/lambda/alertmanager-webhook-{env} --since 1h
   ```

2. **Common issues**:
   - Missing SNS permissions: Check IAM role policy
   - Invalid JSON: Verify Alertmanager webhook format
   - Timeout: Default is 30s, should be sufficient

### API Gateway Issues

1. **Test endpoint directly**:
   ```bash
   curl -X POST <webhook-url> -H "Content-Type: application/json" -d '{}'
   ```

2. **Check API Gateway logs** (if enabled)

3. **Verify CORS** if calling from browser

## Cost Estimates

Per environment:

- **Lambda**: Free tier (1M requests/month) - $0 for typical usage
- **API Gateway**: $1.00 per million requests - ~$0.01/month for moderate use
- **SNS**:
  - Email: Free for first 1,000/month - $0
  - SMS: ~$0.00645 per message in US - varies by volume
- **Secrets Manager**: $0.40/month per secret
- **KMS**: $1/month per key
- **CloudWatch Logs**: Minimal cost for log storage

**Total estimated cost per environment**: ~$2-3/month + SMS costs

## Security Considerations

- SNS topic encrypted with KMS
- Lambda IAM role follows least privilege (only SNS publish + CloudWatch logs)
- Secrets Manager for webhook URL (not exposed in code)
- API Gateway has CORS enabled (adjust for production as needed)
- No authentication on webhook endpoint (rely on URL secrecy)

## Rollback

To remove the infrastructure:

```bash
# Nonprod
cd envs/nonprod
terraform destroy -target=module.alerting
terraform destroy -target=module.irsa_cert_manager

# Prod
cd envs/prod
terraform destroy -target=module.alerting
terraform destroy -target=module.irsa_cert_manager
```

Or destroy everything:
```bash
terraform destroy
```

## References

- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [cert-manager DNS01 Challenges](https://cert-manager.io/docs/configuration/acme/dns01/)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [SNS SMS Best Practices](https://docs.aws.amazon.com/sns/latest/dg/sns-mobile-phone-number-as-subscriber.html)

## Support

For issues or questions:
1. Check CloudWatch Logs for Lambda/API Gateway
2. Review Terraform state and outputs
3. Verify AWS permissions and quotas
4. Test webhook endpoint manually
