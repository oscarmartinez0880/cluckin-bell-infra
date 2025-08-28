# Example Kubernetes Ingress Configurations with WAF Integration

This directory contains example Kubernetes manifests showing how to integrate AWS WAFv2 WebACLs with Application Load Balancers via the AWS Load Balancer Controller.

## Production Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cluckin-bell-api-prod
  namespace: cluckin-bell-prod
  annotations:
    # ALB Configuration
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    
    # TLS Configuration
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:346746763840:certificate/your-cert-arn"
    
    # WAF Integration - CRITICAL: Replace with actual WebACL ARN from Terraform output
    alb.ingress.kubernetes.io/wafv2-acl-arn: "arn:aws:wafv2:us-east-1:346746763840:webacl/cb-prod-webacl/12345678-1234-1234-1234-123456789012"
    
    # Health Check Configuration
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "30"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "3"
    
    # ExternalDNS Integration
    external-dns.alpha.kubernetes.io/hostname: api.cluckn-bell.com
    
  labels:
    app: cluckin-bell-api
    environment: prod
spec:
  rules:
  - host: api.cluckn-bell.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /health
        pathType: Exact
        backend:
          service:
            name: api-service
            port:
              number: 8080
  - host: app.cluckn-bell.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: cluckin-bell-prod
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
  selector:
    app: cluckin-bell-api
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: cluckin-bell-prod
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  selector:
    app: cluckin-bell-web
```

## Dev/QA Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cluckin-bell-api-dev
  namespace: cluckin-bell-dev
  annotations:
    # ALB Configuration
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    
    # TLS Configuration
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:us-east-1:264765154707:certificate/your-dev-cert-arn"
    
    # WAF Integration - CRITICAL: Replace with actual WebACL ARN from Terraform output
    alb.ingress.kubernetes.io/wafv2-acl-arn: "arn:aws:wafv2:us-east-1:264765154707:webacl/cb-devqa-webacl/12345678-1234-1234-1234-123456789012"
    
    # ExternalDNS Integration
    external-dns.alpha.kubernetes.io/hostname: api.dev.cluckn-bell.com
    
  labels:
    app: cluckin-bell-api
    environment: dev
spec:
  rules:
  - host: api.dev.cluckn-bell.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

## Internal/Private ALB Example (No WAF Required)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cluckin-bell-cms-internal
  namespace: cluckin-bell-prod
  annotations:
    # Internal ALB Configuration
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    
    # ExternalDNS for internal zone
    external-dns.alpha.kubernetes.io/hostname: cms.internal.cluckn-bell.com
    
    # NOTE: No WAF annotation needed for internal ALBs
    
  labels:
    app: cluckin-bell-cms
    environment: prod
    access: internal
spec:
  rules:
  - host: cms.internal.cluckn-bell.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: cms-service
            port:
              number: 80
```

## Getting WebACL ARNs

To get the actual WebACL ARNs from your Terraform deployment:

```bash
# For Production cluster
cd terraform/clusters/prod
terraform output waf_web_acl_arn

# For Dev/QA cluster  
cd terraform/clusters/devqa
terraform output waf_web_acl_arn_devqa
```

Example output:
```
waf_web_acl_arn = "arn:aws:wafv2:us-east-1:346746763840:webacl/cb-prod-webacl/a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6"
```

## Testing WAF Rules

### 1. Test Rate Limiting

```bash
# Test API rate limiting (should be blocked after limit)
for i in {1..2100}; do
  curl -s -o /dev/null -w "%{http_code}\n" https://api.cluckn-bell.com/api/test
done
```

### 2. Test Size Restriction

```bash
# Create a large payload (>1MB) for API endpoint
dd if=/dev/zero bs=1048577 count=1 | base64 > large_payload.txt
curl -X POST \
  -H "Content-Type: application/json" \
  -d @large_payload.txt \
  https://api.cluckn-bell.com/api/upload
# Should return 403 Forbidden
```

### 3. Test SQL Injection Protection

```bash
# Test SQL injection attempt (should be blocked)
curl "https://api.cluckn-bell.com/api/users?id=1' OR '1'='1"
# Should return 403 Forbidden
```

### 4. Monitor WAF Metrics

```bash
# View blocked requests in CloudWatch
aws logs filter-log-events \
  --log-group-name /aws/wafv2/cb-prod \
  --start-time $(date -d "1 hour ago" +%s)000 \
  --filter-pattern '[timestamp, request_id, client_ip, uri, action="BLOCK"]'
```

## Troubleshooting

### Common Issues

1. **WAF ARN Not Applied**
   - Verify the annotation is correct: `alb.ingress.kubernetes.io/wafv2-acl-arn`
   - Check AWS Load Balancer Controller logs
   - Ensure ALB Controller has WAF permissions

2. **403 Forbidden Errors**
   - Check WAF blocked request logs
   - Review rule configurations
   - Consider adding exclusions for false positives

3. **ALB Creation Fails**
   - Verify WAF WebACL exists in the same region
   - Check IAM permissions for ALB Controller
   - Ensure subnets are properly tagged

### Verification Commands

```bash
# Check if WAF is associated with ALB
aws wafv2 list-resources-for-web-acl \
  --web-acl-arn "arn:aws:wafv2:us-east-1:ACCOUNT:webacl/cb-prod-webacl/ID" \
  --resource-type APPLICATION_LOAD_BALANCER

# View ALB details
aws elbv2 describe-load-balancers \
  --names k8s-cluckinb-cluckinb-1234567890

# Check ALB Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```