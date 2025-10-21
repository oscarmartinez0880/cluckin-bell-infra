# Alerting Module

This module provisions a complete alerting pipeline for Prometheus Alertmanager with SNS notifications via email and SMS.

## Architecture

```
Alertmanager → API Gateway → Lambda → SNS Topic → Email/SMS
                                         ↓
                                  Secrets Manager
                                  (webhook URL)
```

## Components

1. **SNS Topic**: `alerts-{environment}` for distributing alert notifications
2. **Email Subscription**: Sends formatted alerts to configured email address
3. **SMS Subscription**: Sends alerts to configured phone number
4. **Lambda Function**: `alertmanager-webhook-{environment}` processes Alertmanager payloads
5. **API Gateway HTTP API**: Provides webhook endpoint at `/webhook`
6. **Secrets Manager Secret**: Stores webhook URL for GitOps reference

## Usage

```hcl
module "alerting" {
  source = "../../modules/alerting"

  environment         = "nonprod"
  alert_email         = "alerts@example.com"
  alert_phone         = "+12345678900"
  log_retention_days  = 7

  tags = {
    Environment = "nonprod"
    Project     = "cluckin-bell"
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| environment | Environment name (e.g., nonprod, prod) | string | yes |
| alert_email | Email address for alert notifications | string | yes |
| alert_phone | Phone number for SMS alerts (E.164 format) | string | yes |
| log_retention_days | CloudWatch log retention in days | number | no (default: 7) |
| tags | Tags to apply to all resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| sns_topic_arn | ARN of the SNS topic |
| sns_topic_name | Name of the SNS topic |
| webhook_url | Alertmanager webhook URL |
| webhook_secret_arn | ARN of the Secrets Manager secret |
| webhook_secret_name | Name of the Secrets Manager secret |
| lambda_function_name | Name of the Lambda function |
| lambda_function_arn | ARN of the Lambda function |
| api_gateway_id | ID of the API Gateway |

## Alert Message Format

The Lambda function formats alerts with:

- **Subject**: `[SEVERITY] AlertName - STATUS (environment)`
- **Body**:
  ```
  Alert: <alertname>
  Status: FIRING|RESOLVED
  Severity: <severity>
  Environment: <env>
  Instance: <instance>
  
  Summary:
  <summary from annotations>
  
  Started At: <timestamp>
  
  Labels: <all labels as JSON>
  ```

## Post-Deployment Steps

### 1. Confirm Email Subscription

**Critical**: Email alerts will not work until the subscription is confirmed.

1. Check the email inbox specified in `alert_email`
2. Look for "AWS Notification - Subscription Confirmation" email
3. Click "Confirm subscription" link
4. Verify confirmation page appears

### 2. Configure Alertmanager

Use the webhook URL output in your Alertmanager configuration:

```yaml
receivers:
  - name: 'sns-webhook'
    webhook_configs:
      - url: 'https://your-api-gateway-id.execute-api.us-east-1.amazonaws.com/webhook'
        send_resolved: true
        http_config:
          follow_redirects: true
```

### 3. Use with External Secrets (Optional)

If using External Secrets Operator, reference the Secrets Manager secret:

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
    name: alertmanager-webhook
  data:
    - secretKey: webhook_url
      remoteRef:
        key: alertmanager/webhook-url-nonprod
```

## Testing

Test the webhook manually:

```bash
# Get the webhook URL
WEBHOOK_URL=$(terraform output -raw alerting_webhook_url)

# Send a test alert
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

Check your email and SMS for the test alert.

## Security

- **Encryption**: SNS topic is encrypted with KMS
- **Least Privilege**: Lambda IAM role has minimal permissions (CloudWatch Logs + SNS Publish)
- **CORS**: Configured to allow requests from any origin (adjust as needed for production)
- **Secrets**: Webhook URL stored in Secrets Manager for secure GitOps reference

## Cost Considerations

- **Lambda**: Free tier covers 1M requests/month
- **API Gateway**: $1.00 per million HTTP API requests
- **SNS**: 
  - Email: Free for first 1,000 per month, then $2 per 100,000
  - SMS: Varies by country (~$0.00645 per SMS in US)
- **Secrets Manager**: $0.40 per secret per month + $0.05 per 10,000 API calls

## Troubleshooting

### Email not receiving alerts

1. Check subscription status in SNS console
2. Verify email is confirmed (check spam folder for confirmation email)
3. Check Lambda logs in CloudWatch
4. Test webhook endpoint manually

### SMS not receiving alerts

1. Verify phone number is in E.164 format (+1xxxxxxxxxx for US)
2. Check SNS subscription in console
3. Some regions require SMS opt-in - check AWS SNS SMS settings
4. Review Lambda logs for errors

### Lambda errors

Check CloudWatch Logs at `/aws/lambda/alertmanager-webhook-{environment}` for detailed error messages.

## References

- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [SNS SMS Messaging](https://docs.aws.amazon.com/sns/latest/dg/sns-mobile-phone-number-as-subscriber.html)
- [API Gateway HTTP APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api.html)
