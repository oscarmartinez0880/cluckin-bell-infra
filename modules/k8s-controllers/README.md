# Kubernetes Controllers Module

This module deploys essential Kubernetes controllers for DNS and TLS management on AWS EKS clusters. It includes AWS Load Balancer Controller, cert-manager, and external-dns with proper IRSA (IAM Roles for Service Accounts) configuration.

## Components

### 1. AWS Load Balancer Controller
- Provisions AWS Application Load Balancers (ALB) and Network Load Balancers (NLB)
- Automatically manages security groups and target groups
- Integrates with Kubernetes Ingress resources
- Uses IRSA for secure AWS API access

### 2. cert-manager
- Automates TLS certificate provisioning and renewal
- Configured with Let's Encrypt staging and production issuers
- Uses Route 53 DNS01 challenge for domain validation
- Supports wildcard certificates

### 3. external-dns
- Automatically manages DNS records in Route 53
- Syncs Kubernetes Ingress and Service resources with DNS
- Filters domains based on configuration
- Uses IRSA for secure Route 53 access

## Usage

```hcl
module "k8s_controllers" {
  source = "./modules/k8s-controllers"

  cluster_name = "my-eks-cluster"
  aws_region   = "us-east-1"
  vpc_id       = "vpc-12345678"

  # Enable controllers
  enable_aws_load_balancer_controller = true
  enable_cert_manager                 = true
  enable_external_dns                 = true

  # IRSA role ARNs (created separately)
  aws_load_balancer_controller_role_arn = "arn:aws:iam::123456789012:role/alb-controller-role"
  cert_manager_role_arn                 = "arn:aws:iam::123456789012:role/cert-manager-role"
  external_dns_role_arn                 = "arn:aws:iam::123456789012:role/external-dns-role"

  # Configuration
  letsencrypt_email = "admin@example.com"
  domain_filter     = "example.com"

  # Dependencies
  node_groups = module.eks.eks_managed_node_groups
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| aws_region | AWS region | `string` | `"us-east-1"` | no |
| vpc_id | VPC ID where the EKS cluster is deployed | `string` | n/a | yes |
| enable_aws_load_balancer_controller | Enable AWS Load Balancer Controller | `bool` | `true` | no |
| enable_cert_manager | Enable cert-manager | `bool` | `true` | no |
| enable_external_dns | Enable external-dns | `bool` | `true` | no |
| aws_load_balancer_controller_role_arn | IAM role ARN for AWS Load Balancer Controller | `string` | n/a | yes |
| cert_manager_role_arn | IAM role ARN for cert-manager | `string` | n/a | yes |
| external_dns_role_arn | IAM role ARN for external-dns | `string` | n/a | yes |
| letsencrypt_email | Email address for Let's Encrypt certificate registration | `string` | n/a | yes |
| domain_filter | Domain filter for external-dns (e.g., cluckin-bell.com) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| aws_load_balancer_controller_status | Status of AWS Load Balancer Controller deployment |
| cert_manager_status | Status of cert-manager deployment |
| external_dns_status | Status of external-dns deployment |
| cert_manager_namespace | cert-manager namespace |
| letsencrypt_cluster_issuers | Available Let's Encrypt cluster issuers |

## Prerequisites

1. **EKS Cluster**: A running EKS cluster with OIDC provider enabled
2. **IRSA Roles**: IAM roles for service accounts must be created beforehand
3. **Route 53 Hosted Zone**: Properly configured hosted zone for your domain
4. **Node Groups**: At least one node group must be available for pod scheduling

## IRSA Role Requirements

### AWS Load Balancer Controller IAM Policy
The controller needs permissions to:
- Manage Elastic Load Balancers
- Manage EC2 security groups
- Describe VPC resources
- Create/modify target groups

### cert-manager IAM Policy
The controller needs permissions to:
- Manage Route 53 DNS records for DNS01 challenge
- List hosted zones
- Change resource record sets

### external-dns IAM Policy
The controller needs permissions to:
- List Route 53 hosted zones
- Manage DNS records in specified domains

## Certificate Issuers

The module creates two ClusterIssuers for Let's Encrypt:

### Staging Issuer
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
```
Use for testing and development environments.

### Production Issuer
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
```
Use for production environments.

## Ingress Example

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    cert-manager.io/cluster-issuer: letsencrypt-prod
    external-dns.alpha.kubernetes.io/hostname: app.example.com
spec:
  ingressClassName: alb
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

## Troubleshooting

### Check controller status
```bash
# AWS Load Balancer Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# cert-manager
kubectl get pods -n cert-manager

# external-dns
kubectl get pods -n kube-system -l app.kubernetes.io/name=external-dns
```

### Check ClusterIssuers
```bash
kubectl get clusterissuers
kubectl describe clusterissuer letsencrypt-prod
```

### Check certificate status
```bash
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>
```

## Providers

This module includes provider configurations for both **kubernetes** and **helm** providers that automatically connect to your EKS cluster. You have two options for provider configuration:

### Option 1: Automatic Provider Configuration (Recommended)

The module includes a `providers.tf` file that automatically configures the kubernetes and helm providers using your EKS cluster connection data. This works out-of-the-box with no additional configuration required.

```hcl
module "k8s_controllers" {
  source = "./modules/k8s-controllers"

  cluster_name = "my-eks-cluster"
  aws_region   = "us-east-1"
  vpc_id       = "vpc-12345678"

  # Enable controllers
  enable_aws_load_balancer_controller = true
  enable_cert_manager                 = true
  enable_external_dns                 = true

  # IRSA role ARNs (created separately)
  aws_load_balancer_controller_role_arn = "arn:aws:iam::123456789012:role/alb-controller-role"
  cert_manager_role_arn                 = "arn:aws:iam::123456789012:role/cert-manager-role"
  external_dns_role_arn                 = "arn:aws:iam::123456789012:role/external-dns-role"

  # Configuration
  letsencrypt_email = "admin@example.com"
  domain_filter     = "example.com"
}
```

### Option 2: Override with Aliased Providers (Advanced)

For multi-cluster deployments or when you need explicit control over provider configuration, you can override the module's default providers by mapping aliased providers from your root module:

```hcl
# In your root module
provider "kubernetes" {
  alias = "devqa"
  
  host                   = data.aws_eks_cluster.devqa.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.devqa.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.devqa.token
}

provider "helm" {
  alias = "devqa"
  
  kubernetes {
    host                   = data.aws_eks_cluster.devqa.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.devqa.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.devqa.token
  }
}

module "k8s_controllers" {
  source = "./modules/k8s-controllers"
  
  providers = {
    kubernetes = kubernetes.devqa
    helm       = helm.devqa
  }

  # ... other variables
}
```

## Troubleshooting

### Error: "Failed to construct REST client: no client config"

This error occurs when the kubernetes or helm providers cannot connect to your EKS cluster. Here are the steps to resolve it:

#### 1. Verify AWS Authentication

Ensure you're authenticated with AWS and have access to the EKS cluster:

```bash
# Check AWS authentication
aws sts get-caller-identity

# Update kubeconfig for the cluster
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Test kubectl access
kubectl get nodes
```

#### 2. SSO Authentication

If using AWS SSO, ensure you're logged in:

```bash
# Login to AWS SSO
aws sso login --profile <your-sso-profile>

# Set the profile environment variable
export AWS_PROFILE=<your-sso-profile>

# Verify authentication
aws sts get-caller-identity
```

#### 3. Two-Phase Apply for New Clusters

If you're creating the EKS cluster and k8s-controllers in the same Terraform plan, apply in two phases:

```bash
# Phase 1: Create the EKS cluster first
terraform apply -target="module.eks"

# Phase 2: Apply the k8s-controllers module
terraform apply
```

This ensures the EKS cluster exists before the providers try to connect to it.

#### 4. Check Provider Configuration

If using explicit provider mapping, verify your provider configuration:

```bash
# Check that the cluster exists and is accessible
aws eks describe-cluster --name <cluster-name> --region <region>

# Verify OIDC provider is configured
aws eks describe-cluster --name <cluster-name> --region <region> \
  --query 'cluster.identity.oidc.issuer' --output text
```

#### 5. Provider Version Compatibility

Ensure you're using compatible provider versions:

- **kubernetes provider**: ~> 2.20
- **helm provider**: ~> 2.0
- **aws provider**: ~> 5.0

### Error: "certificate verify failed" or TLS issues

This usually indicates a problem with the cluster certificate authority:

```bash
# Verify cluster endpoint is accessible
curl -k <cluster-endpoint>/healthz

# Check certificate authority data
aws eks describe-cluster --name <cluster-name> --region <region> \
  --query 'cluster.certificateAuthority.data' --output text | base64 -d
```

### Error: "Unauthorized" or 403 errors

This indicates an authentication or authorization issue:

```bash
# Check if your AWS user/role has EKS access
aws eks describe-cluster --name <cluster-name> --region <region>

# Verify aws-auth ConfigMap (if using IAM authentication)
kubectl get configmap aws-auth -n kube-system -o yaml
```

## Version Compatibility

- **AWS Load Balancer Controller**: v1.8.1
- **cert-manager**: v1.15.3
- **external-dns**: v1.14.5
- **Kubernetes**: >= 1.24
- **Terraform**: >= 1.0