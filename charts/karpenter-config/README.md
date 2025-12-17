# Karpenter Configuration

This directory contains Karpenter NodePool and EC2NodeClass configurations for the Cluckin Bell EKS clusters.

## Overview

Karpenter is a flexible, high-performance Kubernetes cluster autoscaler that provisions right-sized compute resources in response to changing application load. It replaces the legacy Cluster Autoscaler approach.

## Directory Structure

- `nonprod/` - NodePool and EC2NodeClass for the nonprod cluster (dev/qa workloads)
- `prod/` - NodePool and EC2NodeClass for the production cluster

## Usage

These manifests should be applied to the cluster after Karpenter has been installed via the Terraform module.

### Nonprod Cluster

```bash
# Apply to nonprod cluster
kubectl apply -f charts/karpenter-config/nonprod/
```

### Prod Cluster

```bash
# Apply to prod cluster
kubectl apply -f charts/karpenter-config/prod/
```

## Configuration Details

### NodePool

The NodePool defines:
- Resource limits (CPU, memory)
- Disruption policies (consolidation, expiration)
- Node requirements (instance types, capacity types)

### EC2NodeClass

The EC2NodeClass defines:
- AMI family (Amazon Linux 2023)
- Subnet and security group selection
- IAM instance profile
- User data for node initialization
- Volume configuration (GP3, encrypted)
- Tags for resource management

## Migration from Cluster Autoscaler

When migrating from Cluster Autoscaler to Karpenter:

1. Install Karpenter via Terraform (set `enable_karpenter = true`)
2. Apply NodePool and EC2NodeClass configurations
3. Gradually scale down existing node groups
4. Remove Cluster Autoscaler deployment
5. Remove cluster-autoscaler tags from node groups

See the main README for detailed migration instructions.
