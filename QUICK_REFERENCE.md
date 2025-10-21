# Quick Reference: Cert-Manager & Alerting Infrastructure

## 🚀 Quick Deploy

```bash
# Nonprod
cd envs/nonprod
terraform init && terraform apply

# Prod  
cd envs/prod
terraform init && terraform apply
```

## 📧 Post-Deploy: Confirm Email (REQUIRED!)

1. Check `oscar21martinez88@gmail.com` inbox
2. Click "Confirm subscription" in AWS email
3. SMS to `+12298051449` auto-confirms

## 🔑 Get Outputs

```bash
# In envs/nonprod or envs/prod
terraform output cert_manager_role_arn
terraform output alerting_webhook_url
terraform output alerting_webhook_secret_name
```

## 🎯 Use in Kubernetes

### cert-manager ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager
  namespace: cert-manager
  annotations:
    eks.amazonaws.com/role-arn: <cert_manager_role_arn>
```

### Alertmanager Webhook

```yaml
receivers:
  - name: 'sns-webhook'
    webhook_configs:
      - url: '<alerting_webhook_url>'
        send_resolved: true
```

## 🧪 Test Webhook

```bash
WEBHOOK_URL=$(terraform output -raw alerting_webhook_url)

curl -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" -d '{
  "version": "4",
  "status": "firing",
  "alerts": [{
    "status": "firing",
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "env": "test"
    },
    "annotations": {
      "summary": "Test alert"
    }
  }]
}'
```

## 📊 Resources Created Per Environment

| Resource | Name Pattern |
|----------|--------------|
| IAM Role | `cluckn-bell-{env}-cert-manager` |
| SNS Topic | `alerts-{env}` |
| Lambda | `alertmanager-webhook-{env}` |
| Secret | `alertmanager/webhook-url-{env}` |

## 📍 Accounts

- **Nonprod** (dev + qa): 264765154707
- **Prod**: 346746763840

## 📖 Full Documentation

- Detailed guide: [CERT_MANAGER_ALERTING_DEPLOYMENT.md](CERT_MANAGER_ALERTING_DEPLOYMENT.md)
- Module docs: [modules/alerting/README.md](modules/alerting/README.md)
- Main README: [README.md](README.md)

## 💰 Cost Estimate

~$2-3/month per environment + SMS costs (~$0.006/SMS)

## 🔍 Troubleshooting

```bash
# Check Lambda logs
aws logs tail /aws/lambda/alertmanager-webhook-{env} --follow

# Check SNS subscriptions
aws sns list-subscriptions-by-topic --topic-arn $(terraform output -raw alerting_sns_topic_arn)

# Get webhook URL from Secrets Manager
aws secretsmanager get-secret-value --secret-id alertmanager/webhook-url-{env} --query SecretString --output text
```
