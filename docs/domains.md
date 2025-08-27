# Domain Configuration for Cluckin' Bell

This document outlines the domain configuration for the Cluckin' Bell application across all environments, including frontend and API hostnames and their mapping to Kubernetes Ingress resources.

## Domain Structure

### Frontend Domains

| Environment | Domain | Account | Description |
|-------------|--------|---------|-------------|
| dev | dev.cluckn-bell.com | 264765154707 (cluckin-bell-qa) | Development environment |
| qa | qa.cluckn-bell.com | 264765154707 (cluckin-bell-qa) | QA/staging environment |
| prod | cluckn-bell.com | 346746763840 (cluckin-bell-prod) | Production environment |

### API Domains

| Environment | Domain | Account | Description |
|-------------|--------|---------|-------------|
| dev | api.dev.cluckn-bell.com | 264765154707 (cluckin-bell-qa) | Development API |
| qa | api.qa.cluckn-bell.com | 264765154707 (cluckin-bell-qa) | QA/staging API |
| prod | api.cluckn-bell.com | 346746763840 (cluckin-bell-prod) | Production API |

## Route 53 Configuration

### Hosted Zones

The following Route 53 hosted zones should be configured:

- **cluckn-bell.com** (in production account 346746763840)
  - Manages: cluckn-bell.com, api.cluckn-bell.com
  - Contains NS records for dev and qa subdomains

- **dev.cluckn-bell.com** (in qa account 264765154707)
  - Manages: dev.cluckn-bell.com, api.dev.cluckn-bell.com

- **qa.cluckn-bell.com** (in qa account 264765154707)  
  - Manages: qa.cluckn-bell.com, api.qa.cluckn-bell.com

### DNS Delegation

Development and QA subdomains are delegated to the QA account (264765154707) via NS records in the main hosted zone.

## Kubernetes Ingress Mapping

### Frontend Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cluckin-bell-frontend
  namespace: cluckin-bell-${env}
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: alb
  tls:
  - hosts:
    - ${frontend_domain}  # dev.cluckn-bell.com, qa.cluckn-bell.com, or cluckn-bell.com
    secretName: cluckin-bell-frontend-tls
  rules:
  - host: ${frontend_domain}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: cluckin-bell-app
            port:
              number: 80
```

### API Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cluckin-bell-api
  namespace: cluckin-bell-${env}
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: alb
  tls:
  - hosts:
    - ${api_domain}  # api.dev.cluckn-bell.com, api.qa.cluckn-bell.com, or api.cluckn-bell.com
    secretName: cluckin-bell-api-tls
  rules:
  - host: ${api_domain}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wingman-api
            port:
              number: 80
```

## SSL/TLS Configuration

### Certificate Management

- Use **cert-manager** with Let's Encrypt for automatic SSL certificate provisioning
- Certificates are automatically renewed before expiration
- Separate certificates for frontend and API domains in each environment

### AWS Certificate Manager Integration

For production workloads, consider using AWS Certificate Manager (ACM) certificates:

```yaml
annotations:
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:${account_id}:certificate/${cert_id}
```

## Load Balancer Configuration

### AWS Load Balancer Controller

The AWS Load Balancer Controller provisions Application Load Balancers (ALBs) for each Ingress:

- **Scheme**: Internet-facing for public access
- **Target Type**: IP mode for direct pod targeting
- **Security Groups**: Automatically managed by the controller
- **SSL Termination**: At the load balancer level

### Health Checks

Configure appropriate health check paths:

- **Frontend**: `/health` or `/`
- **API**: `/health` or `/api/health`

## Environment-Specific Configuration

### Development
- Domain: dev.cluckn-bell.com, api.dev.cluckn-bell.com
- Account: 264765154707 (cluckin-bell-qa)
- Cluster: cluckin-bell-eks-dev-us-east-1
- Namespace: cluckin-bell-dev

### QA
- Domain: qa.cluckn-bell.com, api.qa.cluckn-bell.com  
- Account: 264765154707 (cluckin-bell-qa)
- Cluster: cluckin-bell-eks-qa-us-east-1
- Namespace: cluckin-bell-qa

### Production
- Domain: cluckn-bell.com, api.cluckn-bell.com
- Account: 346746763840 (cluckin-bell-prod)
- Cluster: cluckin-bell-eks-prod-us-east-1
- Namespace: cluckin-bell-prod

## Terraform Configuration

Use the domain locals from `locals/naming.tf`:

```hcl
# Frontend domain for current environment
local.domains.frontend[var.environment]

# API domain for current environment  
local.domains.api[var.environment]
```

## Monitoring and Alerting

Set up CloudWatch alarms and Route 53 health checks for:

- Domain resolution health
- SSL certificate expiration warnings
- Load balancer response times
- API endpoint availability