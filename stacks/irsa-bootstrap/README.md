# IRSA Bootstrap Stack

This Terraform stack creates IAM roles for Kubernetes service accounts (IRSA) for EKS clusters that are managed by eksctl.

## Purpose

After creating an EKS cluster with eksctl, this stack:
1. Creates the IAM OIDC identity provider for the cluster
2. Creates IRSA roles for essential Kubernetes controllers:
   - AWS Load Balancer Controller
   - External DNS
   - Cert Manager

## Prerequisites

- EKS cluster created via eksctl (see `scripts/eks/create-clusters.sh`)
- AWS CLI configured with appropriate profile
- Terraform >= 1.0

## Usage

### 1. Get the OIDC Issuer URL

After creating your cluster with eksctl, get the OIDC issuer URL:

```bash
# For nonprod cluster
aws eks describe-cluster \
  --name cluckn-bell-nonprod \
  --region us-east-1 \
  --profile cluckin-bell-qa \
  --query 'cluster.identity.oidc.issuer' \
  --output text

# For prod cluster
aws eks describe-cluster \
  --name cluckn-bell-prod \
  --region us-east-1 \
  --profile cluckin-bell-prod \
  --query 'cluster.identity.oidc.issuer' \
  --output text
```

### 2. Create a tfvars file

Create `nonprod.tfvars`:
```hcl
cluster_name    = "cluckn-bell-nonprod"
region          = "us-east-1"
aws_profile     = "cluckin-bell-qa"
oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/XXXXX"
environment     = "nonprod"
controllers_namespace = "kube-system"
```

Or for production, create `prod.tfvars`:
```hcl
cluster_name    = "cluckn-bell-prod"
region          = "us-east-1"
aws_profile     = "cluckin-bell-prod"
oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/YYYYY"
environment     = "prod"
controllers_namespace = "kube-system"
```

### 3. Apply the stack

```bash
# Initialize Terraform
terraform init

# Plan
terraform plan -var-file=nonprod.tfvars

# Apply
terraform apply -var-file=nonprod.tfvars
```

### 4. Use the outputs

After applying, Terraform will output the IAM role ARNs. Use these in your Helm values or Argo CD applications:

```bash
terraform output helm_values
```

Example output:
```yaml
# AWS Load Balancer Controller
aws-load-balancer-controller:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::264765154707:role/cluckn-bell-nonprod-aws-lb-controller

# External DNS
external-dns:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::264765154707:role/cluckn-bell-nonprod-external-dns

# Cert Manager
cert-manager:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: arn:aws:iam::264765154707:role/cluckn-bell-nonprod-cert-manager
```

## Created Resources

- **IAM OIDC Identity Provider**: Enables IRSA for the cluster
- **IAM Role for AWS Load Balancer Controller**: Full permissions to manage ALBs/NLBs
- **IAM Role for External DNS**: Route53 permissions for DNS management
- **IAM Role for Cert Manager**: Route53 permissions for DNS-01 challenges

## Important Notes

- This stack should be run **after** creating the cluster with eksctl
- The OIDC issuer URL must match exactly (including `https://` prefix)
- Run this stack separately for each cluster (nonprod and prod)
- Use Argo CD or Helm to deploy the actual controllers with these IAM roles
