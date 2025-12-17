# eksctl Cluster Configurations

This directory contains eksctl configuration files for managing EKS clusters in the cluckin-bell infrastructure.

## Files

- **devqa-cluster.yaml**: Configuration for the shared nonprod cluster (cluckn-bell-nonprod)
  - Account: 264765154707 (cluckin-bell-qa)
  - Node groups: `dev` and `qa`
  - Kubernetes version: 1.33
  
- **prod-cluster.yaml**: Configuration for the production cluster (cluckn-bell-prod)
  - Account: 346746763840 (cluckin-bell-prod)
  - Node group: `prod`
  - Kubernetes version: 1.33

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
eksctl create cluster --config-file=eksctl/devqa-cluster.yaml

# Prod
export AWS_PROFILE=cluckin-bell-prod
eksctl create cluster --config-file=eksctl/prod-cluster.yaml
```

### Upgrading

To upgrade Kubernetes version or update node group configurations:

1. Edit the YAML file
2. Run:
   ```bash
   eksctl upgrade cluster --config-file=eksctl/devqa-cluster.yaml --profile=cluckin-bell-qa --approve
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
- **Instance Types**: m7i (7th generation Intel instances for better performance)
- **Add-ons**: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, eks-pod-identity-agent
- **Logging**: CloudWatch with appropriate retention (7 days nonprod, 90 days prod)
- **Karpenter Support**: Nodes tagged for Karpenter discovery

## Cost Optimization

- Start with minimal desired node counts
- Use cluster autoscaler to scale based on demand
- AL2023 AMI has no license cost
- Monitor and adjust instance types based on actual usage

## Karpenter Migration Path

For organizations looking to migrate from Cluster Autoscaler to Karpenter:

1. **Enable Karpenter IAM resources** via Terraform:
   ```bash
   cd envs/nonprod
   # Edit nonprod.auto.tfvars or nonprod.tfvars
   # Set: enable_karpenter = true
   terraform plan
   terraform apply
   ```

2. **Deploy Karpenter** via ArgoCD (recommended) or Helm:
   - Karpenter controller and CRDs are managed as Kubernetes resources
   - Use the controller IAM role ARN from Terraform outputs
   - Configure NodePools and EC2NodeClasses via Kubernetes manifests

3. **Gradual migration**:
   - Run Karpenter alongside Cluster Autoscaler initially
   - Migrate workloads to Karpenter-managed nodes progressively
   - Scale down or remove Cluster Autoscaler node groups once migration is complete

4. **Benefits**:
   - Faster scaling (seconds vs minutes)
   - Better bin-packing and cost optimization
   - Support for diverse instance types and spot instances
   - Native support for pod-level disruption budgets

Note: Karpenter itself (controller, CRDs, NodePools) is NOT managed by Terraform to follow EKS best practices of separating infrastructure (AWS resources) from Kubernetes resources.
