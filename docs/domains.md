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

## Safe DNS Defaults

### Overview

The infrastructure is configured with safe-by-default DNS management to prevent accidental deletion or recreation of Route53 hosted zones. This is critical because recreating a hosted zone changes its nameservers, which can cause extended DNS outages.

### Protection Mechanisms

#### 1. Reuse Existing Zones (Recommended)

Set `create = false` in the zone configuration to adopt existing zones without creating new ones:

```hcl
module "dns_certs" {
  source = "../../modules/dns-certs"

  public_zone = {
    name   = "cluckn-bell.com"
    create = false  # Reuse existing zone, do not create
  }

  private_zone = {
    name   = "internal.cluckn-bell.com"
    create = false  # Reuse existing zone, do not create
    vpc_id = local.vpc_id
  }
}
```

When `create = false`:
- Terraform uses a data source to look up the existing zone
- No zone creation or deletion operations are performed
- Safe to run `terraform plan` and `terraform apply`

#### 2. Lifecycle Protection for Managed Zones

For zones that Terraform creates and manages with the default settings (`allow_zone_destroy = false`), the `dns-certs` module includes `lifecycle { prevent_destroy = true }`.

**Implementation Note:** Due to Terraform's requirement that `prevent_destroy` must be a literal boolean (not variable-derived), the module uses a dual-resource approach:
- Protected resources (used by default) have `prevent_destroy = true`
- Unprotected resources (only used when `allow_zone_destroy = true`) have no lifecycle block
- Count expressions ensure only one version is created based on the `allow_zone_destroy` variable

```hcl
# Protected version (default)
resource "aws_route53_zone" "public" {
  count = var.public_zone.create && !var.allow_zone_destroy ? 1 : 0
  # ... configuration ...

  lifecycle {
    prevent_destroy = true
  }
}

# Unprotected version (opt-in only)
resource "aws_route53_zone" "public_unprotected" {
  count = var.public_zone.create && var.allow_zone_destroy ? 1 : 0
  # ... configuration ...
}
```

This prevents Terraform from deleting zones even if:
- The configuration changes to `create = false`
- The module is removed from the configuration
- Resource names or arguments change

#### 3. Explicit Opt-In for Zone Deletion

To intentionally remove a zone managed by Terraform, you must explicitly allow it:

```hcl
module "dns_certs" {
  source = "../../modules/dns-certs"

  # ... other configuration ...

  allow_zone_destroy = true  # Required to delete zones
}
```

**Warning:** Only set `allow_zone_destroy = true` when you intentionally want to delete a hosted zone.

### Environment-Specific Defaults

#### Production (envs/prod)

- **Public zone** (`cluckn-bell.com`): `create = false` by default (reuses existing apex zone)
- **Private zone** (`internal.cluckn-bell.com`): `create = true` (creates new internal zone)
- **Protection**: `allow_zone_destroy = false` (explicit in module call)
- **Additional**: The legacy private zone at `terraform/clusters/prod/dns-internal.tf` also has `lifecycle { prevent_destroy = true }`

#### Nonprod (envs/nonprod)

- **Dev public zone** (`dev.cluckn-bell.com`): `create = false` (reuses existing zone from terraform/dns)
- **QA public zone** (`qa.cluckn-bell.com`): `create = false` (reuses existing zone from terraform/dns)
- **Shared private zone** (`cluckn-bell.com`): `create = true` in dev module, reused by qa module
- **Protection**: `allow_zone_destroy = false` (default, not overridden)

### Migrating to Existing Zones

If Terraform currently manages a zone but you want to switch to an existing zone:

#### Option 1: State Removal (Preferred)

```bash
# Remove the zone from Terraform state
terraform state rm 'module.dns_certs.aws_route53_zone.public[0]'

# Update configuration to create = false
# Run plan to verify no changes
terraform plan
```

This removes Terraform management without deleting the zone.

#### Option 2: Import Existing Zone

```bash
# If you need to manage a pre-existing zone with Terraform:
terraform import 'module.dns_certs.aws_route53_zone.public[0]' Z1234567890ABC
```

### Importing Existing Zones

To adopt an existing hosted zone into Terraform management:

```bash
# 1. Configure the module with create = true
# 2. Import the existing zone
terraform import 'module.dns_certs.aws_route53_zone.public[0]' <ZONE_ID>

# 3. Run plan to ensure no changes
terraform plan
```

### Best Practices

1. **Always use `create = false` for production apex zones** - These zones should be created once manually or via dedicated infrastructure, not recreated frequently.

2. **Run from environment directories** - Avoid running Terraform from the repository root where legacy `route53.tf` exists. Use:
   - `envs/prod/`
   - `envs/nonprod/`
   - `terraform/dns/` (for initial zone setup only)

3. **Test in nonprod first** - Always test DNS configuration changes in dev/qa before applying to production.

4. **Use separate zones for internal services** - Private zones like `internal.cluckn-bell.com` separate internal traffic from public DNS.

5. **Document zone ownership** - Maintain clear documentation of which Terraform configuration manages which zones.

### Validation Records and NS Records

The following changes are expected and safe:
- **Validation records** (`_acme-challenge.*`) may be replaced as ACM tokens rotate
- **NS delegation records** for subdomains may change if nameservers are updated
- **Certificate validation** recreates validation records during certificate renewals

These operations do **not** recreate the hosted zone itself and are safe.

### Troubleshooting

#### Scenario: "Error: cannot destroy protected resource"

If you see:
```
Error: Instance cannot be destroyed
  on modules/dns-certs/main.tf line XX:
  resource "aws_route53_zone" "public" {
```

**Solution**: This is the protection working as intended. If you really want to remove the zone:
1. Set `allow_zone_destroy = true` in the module call
2. Run `terraform apply`

Alternatively, use `terraform state rm` to stop managing the zone without deleting it.

#### Scenario: "Zone already exists" on first apply

If Terraform tries to create a zone that already exists:

**Solution**: Change `create = true` to `create = false` to reuse the existing zone instead.

### Legacy Route53 Configuration

The file `/route53.tf` at the repository root contains legacy zone definitions. **Do not run Terraform from the root directory** as this may conflict with environment-specific configurations. This file is kept for reference but should not be actively managed.