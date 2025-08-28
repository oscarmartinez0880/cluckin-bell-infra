# AWS WAFv2 Security Baseline Documentation

## Overview

This implementation establishes a robust security baseline using AWS WAFv2 for public Application Load Balancers (ALBs) and enhances cluster-level observability with CloudWatch Container Insights.

## WAF WebACL Configuration

### Environments

- **Production (`cb-prod`)**: Full security controls with Bot Control enabled
- **Dev/QA (`cb-devqa`)**: Cost-optimized configuration with higher rate limits

### Managed Rule Groups

All environments include these AWS managed rule groups:

1. **AWSManagedRulesCommonRuleSet (CRS)** - Core security protections
2. **AWSManagedRulesKnownBadInputsRuleSet** - Known malicious inputs
3. **AWSManagedRulesAmazonIpReputationList** - IP reputation filtering
4. **AWSManagedRulesSQLiRuleSet** - SQL injection protection
5. **AWSManagedRulesLinuxRuleSet** - Linux-specific protections
6. **AWSManagedRulesBotControlRuleSet** - Bot protection (production only)

### Custom Security Rules

#### 1. API Rate Limiting
- **Production**: 2,000 requests per 5 minutes for `/api` paths
- **Dev/QA**: 5,000 requests per 5 minutes for `/api` paths
- **Action**: Block

#### 2. Request Size Restriction
- **Scope**: `/api` paths
- **Limit**: 1MB request body size
- **Action**: Block

#### 3. Geographic Blocking (Optional)
- **Configuration**: Variable-controlled country code list
- **Default**: Empty (no blocking)
- **Action**: Block

#### 4. Admin Path Allow-listing (Optional)
- **Scope**: `/wp-admin` paths
- **Configuration**: IP-based allow list
- **Default**: Empty (no restrictions)
- **Action**: Allow

## ALB Association Methods

### Method 1: Ingress Annotation (Recommended)

Add the WAF WebACL ARN as an annotation to your Kubernetes Ingress resources:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    # WAF Association
    alb.ingress.kubernetes.io/wafv2-acl-arn: "arn:aws:wafv2:us-east-1:ACCOUNT:webacl/cb-prod-webacl/WEBACL-ID"
spec:
  rules:
  - host: api.cluckn-bell.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 80
```

### Method 2: Terraform Association (Fallback)

If ingress annotations are not suitable, you can associate WAF WebACLs directly to ALBs using Terraform:

```hcl
# Data source to find ALB by tags
data "aws_lb" "app_alb" {
  tags = {
    "kubernetes.io/ingress-name" = "app-ingress"
    "kubernetes.io/namespace"    = "default"
  }
}

# Associate WAF WebACL to ALB
resource "aws_wafv2_web_acl_association" "app_alb" {
  resource_arn = data.aws_lb.app_alb.arn
  web_acl_arn  = module.waf_prod.web_acl_arn
}
```

## WebACL ARNs by Environment

The WebACL ARNs are available as Terraform outputs:

- **Production**: `module.waf_prod.web_acl_arn`
- **Dev/QA**: `module.waf_devqa.web_acl_arn`

Example output values:
```
waf_web_acl_arn_prod = "arn:aws:wafv2:us-east-1:346746763840:webacl/cb-prod-webacl/12345678-1234-1234-1234-123456789012"
waf_web_acl_arn_devqa = "arn:aws:wafv2:us-east-1:264765154707:webacl/cb-devqa-webacl/12345678-1234-1234-1234-123456789012"
```

## CloudWatch Container Insights

### Features Enabled

1. **Performance Metrics**: CPU, memory, network, and disk utilization
2. **Application Logs**: Structured logging with log correlation
3. **Node and Pod Metrics**: Detailed Kubernetes resource metrics
4. **Log Aggregation**: Centralized logging for troubleshooting

### Log Groups Created

- `/aws/containerinsights/{cluster-name}/performance`
- `/aws/containerinsights/{cluster-name}/application`
- `/aws/containerinsights/{cluster-name}/dataplane`
- `/aws/containerinsights/{cluster-name}/host`

### Retention Policies

- **Production**: 30 days
- **Dev/QA**: 7 days

## Monitoring and Alerting

### WAF Metrics Available

All rules generate CloudWatch metrics:
- `CommonRuleSetMetric`
- `KnownBadInputsMetric`
- `AmazonIpReputationListMetric`
- `SQLiRuleSetMetric`
- `LinuxRuleSetMetric`
- `BotControlRuleSetMetric` (production only)
- `APIRateLimitMetric`
- `APISizeRestrictionMetric`
- `GeoBlockingMetric` (if enabled)
- `AdminPathAllowlistMetric` (if enabled)

### Sample CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "waf-blocked-requests-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "This metric monitors blocked requests by WAF"
  
  dimensions = {
    WebACL = "cb-prod-webacl"
    Region = "us-east-1"
  }
}
```

## Security Best Practices

### 1. Regular Rule Updates
- AWS managed rules are automatically updated
- Monitor AWS security bulletins for new rule groups

### 2. Rate Limit Tuning
- Start with conservative limits
- Monitor legitimate traffic patterns
- Adjust based on application requirements

### 3. Log Analysis
- Enable WAF logging in production
- Regular review of blocked requests
- Tune rules based on false positives

### 4. Incident Response
- Establish procedures for WAF-related incidents
- Document emergency bypass procedures
- Regular security reviews

## Cost Optimization

### Production vs Dev/QA Differences

| Feature | Production | Dev/QA | Reason |
|---------|------------|---------|---------|
| Bot Control | Enabled | Disabled | Cost savings |
| WAF Logging | Enabled | Disabled | Reduced log costs |
| Rate Limits | 2,000/5min | 5,000/5min | Testing flexibility |
| Log Retention | 30 days | 7 days | Compliance vs cost |

### Monthly Cost Estimates

- **WAF WebACL**: $1.00/month per WebACL
- **Managed Rules**: $1.00-$10.00/month per rule group (depending on requests)
- **Bot Control**: $10.00/month + $1.00 per million requests
- **CloudWatch Logs**: $0.50 per GB ingested + $0.03 per GB stored

## Troubleshooting

### Common Issues

1. **False Positives**
   - Review blocked request samples in CloudWatch
   - Consider rule exclusions for specific patterns
   - Adjust size limits for legitimate large requests

2. **Performance Impact**
   - Monitor ALB response times
   - WAF processing adds minimal latency (<1ms typical)

3. **Log Volume**
   - Monitor CloudWatch costs
   - Adjust retention policies as needed
   - Use log filters to reduce noise

### Debugging Commands

```bash
# Get WAF WebACL details
aws wafv2 get-web-acl --scope REGIONAL --id WEBACL-ID --region us-east-1

# List blocked requests
aws logs filter-log-events \
  --log-group-name /aws/wafv2/cb-prod \
  --filter-pattern '[timestamp, request_id, client_ip, uri, action="BLOCK"]'

# Check Container Insights metrics
aws logs describe-log-groups --log-group-name-prefix "/aws/containerinsights/"
```

## Next Steps

1. **Deploy WAF WebACLs** - Apply Terraform configurations
2. **Update Ingress Resources** - Add WAF annotations to ALB ingresses
3. **Monitor Traffic** - Review initial WAF metrics and logs
4. **Tune Rules** - Adjust rate limits and rules based on traffic patterns
5. **Set Up Alerting** - Create CloudWatch alarms for security events