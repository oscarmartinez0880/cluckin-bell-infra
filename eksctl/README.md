# eksctl Cluster Configurations

This directory contains eksctl configuration files for managing EKS clusters in the cluckin-bell infrastructure.

## Files

- **nonprod-cluster.yaml**: Configuration for the shared nonprod cluster (cluckn-bell-nonprod)
  - Account: 264765154707 (cluckin-bell-qa)
  - Node groups: `dev` and `qa`
  - Kubernetes version: 1.34
  
- **prod-cluster.yaml**: Configuration for the production cluster (cluckn-bell-prod)
  - Account: 346746763840 (cluckin-bell-prod)
  - Node group: `prod`
  - Kubernetes version: 1.34

## Prerequisites

Before using these configurations:

1. Deploy VPCs and networking via Terraform:
   ```bash
   cd terraform/clusters/devqa
   terraform init
   terraform apply
   ```

2. Update the placeholder values in the YAML files:
   - Replace `vpc-REPLACE_WITH_VPC_ID` with the actual VPC ID
   - Replace `subnet-REPLACE_WITH_SUBNET_*` with actual subnet IDs
   
   Get these values from Terraform outputs:
   ```bash
   cd terraform/clusters/devqa
   terraform output
   ```

## Usage

### Quick Start

Use the provided script:
```bash
# Create nonprod cluster
./scripts/eks/create-clusters.sh nonprod

# Create prod cluster
./scripts/eks/create-clusters.sh prod

# Create both
./scripts/eks/create-clusters.sh all
```

### Manual Creation

```bash
# Nonprod
export AWS_PROFILE=cluckin-bell-qa
eksctl create cluster --config-file=eksctl/nonprod-cluster.yaml

# Prod
export AWS_PROFILE=cluckin-bell-prod
eksctl create cluster --config-file=eksctl/prod-cluster.yaml
```

### Upgrading

To upgrade Kubernetes version or update node group configurations:

1. Edit the YAML file
2. Run:
   ```bash
   eksctl upgrade cluster --config-file=eksctl/nonprod-cluster.yaml --profile=cluckin-bell-qa --approve
   ```

### Scaling

Scale node groups:
```bash
eksctl scale nodegroup \
  --cluster=cluckn-bell-nonprod \
  --name=dev \
  --nodes=3 \
  --profile=cluckin-bell-qa
```

## Next Steps

After cluster creation:

1. **Get OIDC issuer URL**:
   ```bash
   aws eks describe-cluster \
     --name cluckn-bell-nonprod \
     --region us-east-1 \
     --profile cluckin-bell-qa \
     --query 'cluster.identity.oidc.issuer' \
     --output text
   ```

2. **Bootstrap IRSA roles**:
   ```bash
   cd stacks/irsa-bootstrap
   terraform init
   terraform apply -var-file=nonprod.tfvars
   ```

3. **Deploy controllers via Helm/Argo CD**

## Documentation

For complete documentation, see [docs/CLUSTERS_WITH_EKSCTL.md](../docs/CLUSTERS_WITH_EKSCTL.md)

## Architecture

Both clusters use:
- **AMI**: Amazon Linux 2023 (AL2023)
- **Network**: Private subnets only (no public endpoints)
- **Add-ons**: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver
- **Logging**: CloudWatch with appropriate retention (7 days nonprod, 90 days prod)

## Cost Optimization

- Start with minimal desired node counts
- Use cluster autoscaler to scale based on demand
- AL2023 AMI has no license cost
- Monitor and adjust instance types based on actual usage
