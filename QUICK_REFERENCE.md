# Quick Reference: Cluster Lifecycle & Infrastructure

## 🎛️ On-Demand EKS Cluster Lifecycle (Cost Minimization)

### Start/Stop Clusters

```bash
# QA/Dev (Nonprod Cluster)
make cluster-up-qa      # Start cluster (~15-20 min)
make cluster-down-qa    # Stop cluster (~10-15 min, requires confirmation)

# Production
make cluster-up-prod    # Start cluster (~15-20 min)
make cluster-down-prod  # Stop cluster (~10-15 min, requires confirmation)
```

### Testing the Lifecycle Controls

#### Local Testing (Recommended for Validation)

**Prerequisites:**
- AWS CLI configured with SSO profiles
- eksctl installed (`brew install eksctl` or see https://eksctl.io/)
- kubectl installed

**Test Steps for QA:**

```bash
# 1. Ensure SSO login (will be prompted automatically by make targets)
aws sso login --profile cluckin-bell-qa

# 2. Verify credentials
aws sts get-caller-identity --profile cluckin-bell-qa
# Should show account: 264765154707

# 3. Start the nonprod cluster
make cluster-up-qa
# Expected: Creates cluster cluckn-bell-nonprod with 2 node groups (dev, qa)
# Wait ~15-20 minutes

# 4. Verify cluster is running
aws eks describe-cluster --name cluckn-bell-nonprod --region us-east-1 --profile cluckin-bell-qa
aws eks list-nodegroups --cluster-name cluckn-bell-nonprod --region us-east-1 --profile cluckin-bell-qa

# 5. Update kubeconfig and access cluster
aws eks update-kubeconfig --name cluckn-bell-nonprod --region us-east-1 --profile cluckin-bell-qa
kubectl get nodes
kubectl get nodes -o wide

# 6. Verify node configuration
kubectl get nodes --show-labels
# Should see 2 nodes: t3.small instances (1 dev, 1 qa)

# 7. Stop the cluster to minimize costs
make cluster-down-qa
# Enter "yes" when prompted
# Wait ~10-15 minutes

# 8. Verify cluster is deleted
aws eks describe-cluster --name cluckn-bell-nonprod --region us-east-1 --profile cluckin-bell-qa
# Expected: Error - cluster not found (this is correct)
```

**Test Steps for Prod:**

```bash
# 1. Login to prod account
aws sso login --profile cluckin-bell-prod

# 2. Verify credentials
aws sts get-caller-identity --profile cluckin-bell-prod
# Should show account: 346746763840

# 3. Start prod cluster
make cluster-up-prod
# Expected: Creates cluster cluckn-bell-prod with 1 node group (prod)

# 4. Verify cluster
aws eks describe-cluster --name cluckn-bell-prod --region us-east-1 --profile cluckin-bell-prod
aws eks list-nodegroups --cluster-name cluckn-bell-prod --region us-east-1 --profile cluckin-bell-prod

# 5. Access cluster
aws eks update-kubeconfig --name cluckn-bell-prod --region us-east-1 --profile cluckin-bell-prod
kubectl get nodes
# Should see 2 nodes: t3.medium instances

# 6. Stop cluster
make cluster-down-prod
# Enter "yes" when prompted
```

### Cluster Configurations

| Environment | Cluster Name | Account | Instance Type | Nodes (min/desired/max) | Disk | K8s Version |
|-------------|--------------|---------|---------------|------------------------|------|-------------|
| **Nonprod (dev)** | cluckn-bell-nonprod | 264765154707 | t3.small | 0/1/2 | 20GB | 1.30 |
| **Nonprod (qa)** | cluckn-bell-nonprod | 264765154707 | t3.small | 0/1/2 | 20GB | 1.30 |
| **Prod** | cluckn-bell-prod | 346746763840 | t3.medium | 1/2/5 | 50GB | 1.30 |

### Cost Impact

**When cluster is UP:**
- Nonprod: ~$30-40/month (2x t3.small + control plane)
- Prod: ~$80-100/month (2x t3.medium + control plane)

**When cluster is DOWN:**
- $0 for EKS (cluster fully deleted)
- VPC/IAM costs remain minimal (~$1-10/month)

### Troubleshooting

```bash
# Check if eksctl is installed
eksctl version

# Check if AWS CLI SSO is configured
aws configure list-profiles
# Should see: cluckin-bell-qa, cluckin-bell-prod

# Check SSO session status
aws sts get-caller-identity --profile cluckin-bell-qa
aws sts get-caller-identity --profile cluckin-bell-prod

# List all clusters in an account
aws eks list-clusters --region us-east-1 --profile cluckin-bell-qa
aws eks list-clusters --region us-east-1 --profile cluckin-bell-prod

# View cluster details
eksctl get cluster --name cluckn-bell-nonprod --region us-east-1 --profile cluckin-bell-qa
eksctl get cluster --name cluckn-bell-prod --region us-east-1 --profile cluckin-bell-prod
```

---

# Cert-Manager & Alerting Infrastructure

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
