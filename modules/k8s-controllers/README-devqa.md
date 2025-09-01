# k8s-controllers Module - DevQA Environment Guide

This guide provides specific information for using the k8s-controllers module in the DevQA shared cluster environment.

## DevQA Environment Overview

The DevQA environment uses a shared EKS cluster model where both development and QA workloads run in the same cluster but are separated by namespaces and resource quotas.

| Environment | Cluster Name | Namespace | Domain |
|-------------|--------------|-----------|--------|
| **dev** | cb-devqa-use1 | cluckin-bell-dev | dev.cluckin-bell.com |
| **qa** | cb-devqa-use1 | cluckin-bell-qa | qa.cluckin-bell.com |

## External DNS Configuration for DevQA

In the DevQA environment, external-dns is configured with **empty domain filters** and relies on **zone ID filters** instead. This allows managing multiple domains in the shared cluster.

### Key Configuration Differences

```hcl
module "k8s_controllers" {
  source = "./modules/k8s-controllers"

  cluster_name = "cb-devqa-use1"
  aws_region   = "us-east-1"
  vpc_id       = var.vpc_id

  # Enable controllers
  enable_aws_load_balancer_controller = true
  enable_cert_manager                 = true
  enable_external_dns                 = true

  # DevQA-specific: Empty domain filter, rely on zone ID filters
  domain_filter = ""
  zone_id_filters = [
    "Z1234567890ABC",  # dev.cluckin-bell.com zone
    "Z0987654321DEF"   # qa.cluckin-bell.com zone
  ]

  # IRSA role ARNs
  aws_load_balancer_controller_role_arn = var.aws_load_balancer_controller_role_arn
  cert_manager_role_arn                 = var.cert_manager_role_arn
  external_dns_role_arn                 = var.external_dns_role_arn

  # Certificate configuration
  letsencrypt_email = "devops@cluckin-bell.com"

  # Namespace for platform controllers
  namespace = "kube-system"

  # Dependencies
  node_groups = module.eks.eks_managed_node_groups
}
```

### Why Empty Domain Filter?

With `domain_filter = ""`, external-dns will manage DNS records for any domain but only within the specified zone IDs. This allows:

1. **Dev services** to create DNS records in the `dev.cluckin-bell.com` zone
2. **QA services** to create DNS records in the `qa.cluckin-bell.com` zone  
3. **Shared controllers** to manage both domains from a single installation

## Example Ingress Configurations

### Development Service Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cluckin-bell-app-dev
  namespace: cluckin-bell-dev
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT:certificate/dev-cert-id
    external-dns.alpha.kubernetes.io/hostname: app.dev.cluckin-bell.com
spec:
  rules:
  - host: app.dev.cluckin-bell.com
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

### QA Service Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cluckin-bell-app-qa
  namespace: cluckin-bell-qa
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT:certificate/qa-cert-id
    external-dns.alpha.kubernetes.io/hostname: app.qa.cluckin-bell.com
spec:
  rules:
  - host: app.qa.cluckin-bell.com
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

## Certificate Management in DevQA

The module creates two ClusterIssuers that can be used across all namespaces:

- **letsencrypt-staging**: For development and testing
- **letsencrypt-prod**: For production-like QA testing

### Using cert-manager with Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: cluckin-bell-app-dev
  namespace: cluckin-bell-dev
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    cert-manager.io/cluster-issuer: letsencrypt-staging
    external-dns.alpha.kubernetes.io/hostname: app.dev.cluckin-bell.com
spec:
  tls:
  - hosts:
    - app.dev.cluckin-bell.com
    secretName: app-dev-tls
  rules:
  - host: app.dev.cluckin-bell.com
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

## Monitoring and Troubleshooting

### Check external-dns logs

```bash
kubectl logs -n kube-system deployment/external-dns
```

### Verify zone ID filters are working

```bash
# Check external-dns configuration
kubectl get deployment external-dns -n kube-system -o yaml | grep -A 10 -B 10 zoneIdFilters

# Check DNS records being managed
kubectl logs -n kube-system deployment/external-dns | grep "Desired change"
```

### Check certificate issuers

```bash
# List available cluster issuers
kubectl get clusterissuer

# Check issuer status
kubectl describe clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-prod
```

## Best Practices for DevQA

1. **Use staging certificates** for development workloads to avoid Let's Encrypt rate limits
2. **Use production certificates** only for QA environments that need production-like SSL
3. **Namespace isolation**: Keep dev and qa workloads in separate namespaces
4. **Resource quotas**: Set appropriate resource limits for each namespace
5. **DNS naming**: Use clear subdomain patterns (`app.dev.cluckin-bell.com`, `api.dev.cluckin-bell.com`)

## Common Issues and Solutions

### Issue: DNS records not being created

**Symptoms**: Ingress is created but DNS record doesn't appear in Route 53

**Solution**: 
1. Check that the correct zone ID is in `zone_id_filters`
2. Verify external-dns has proper IAM permissions for the zones
3. Check external-dns logs for errors

### Issue: Certificates not being issued

**Symptoms**: TLS secret is not created or certificate status shows errors

**Solution**:
1. Verify the ClusterIssuer is ready: `kubectl get clusterissuer`
2. Check cert-manager logs: `kubectl logs -n kube-system deployment/cert-manager`
3. Verify Route 53 permissions for DNS01 challenge

### Issue: Load balancer not provisioned

**Symptoms**: Ingress has no ADDRESS assigned

**Solution**:
1. Check AWS Load Balancer Controller logs: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`
2. Verify subnet tags for load balancer discovery
3. Check security group configurations