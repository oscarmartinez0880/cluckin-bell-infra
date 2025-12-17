# EKS 2025 Best Practices

This document outlines the 2025 best practices for Amazon EKS that have been implemented in this infrastructure.

## Overview

The infrastructure has been updated to align with AWS EKS best practices as of late 2024/early 2025. These changes improve security, performance, cost efficiency, and operational excellence.

## Kubernetes Version

### Current Configuration
- **Version**: 1.33
- **Update Policy**: Stay within 2 versions of latest stable release

### Why 1.33?

Kubernetes 1.33 represents a modern, stable version that includes:
- Security improvements and CVE fixes
- Performance optimizations
- Support for latest Kubernetes features
- Full compatibility with EKS managed add-ons

### Version Management

```hcl
# Terraform validation ensures minimum version
variable "kubernetes_version" {
  type    = string
  default = "1.33"
  validation {
    condition     = can(regex("^1\\.(3[3-9]|[4-9][0-9])(\\..*)?$", var.kubernetes_version))
    error_message = "Kubernetes version must be 1.33 or higher."
  }
}
```

**Upgrade Cadence**:
- Review new versions quarterly
- Test in nonprod first
- Upgrade prod within 1 month of nonprod validation
- Never fall more than 2 versions behind latest

## EKS Pod Identity

### What is EKS Pod Identity?

EKS Pod Identity is a new authentication method for Kubernetes workloads to access AWS services, simplifying the traditional IRSA (IAM Roles for Service Accounts) approach.

### Benefits over IRSA

| Feature | IRSA | EKS Pod Identity |
|---------|------|------------------|
| **Setup Complexity** | Requires OIDC provider | Managed by EKS |
| **Credential Rotation** | Manual webhook | Automatic by AWS |
| **Configuration** | Service account annotations | Pod Identity associations |
| **Overhead** | OIDC token validation | Native EKS integration |
| **Scalability** | Limited by OIDC | Highly scalable |

### Implementation

**Add-on Installation** (in eksctl configs):
```yaml
addons:
  - name: eks-pod-identity-agent
    version: latest
```

**Terraform Module Usage**:
```hcl
resource "aws_eks_pod_identity_association" "example" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "karpenter"
  role_arn        = aws_iam_role.karpenter_controller.arn
}
```

**When to Use**:
- ✅ New workloads requiring AWS permissions
- ✅ Services that benefit from automatic credential rotation
- ✅ Simplified IAM integration
- ⚠️ Requires eks-pod-identity-agent add-on

**When to Use IRSA**:
- ✅ Existing workloads (backward compatibility)
- ✅ Multi-cluster setups requiring same role
- ✅ Complex OIDC federation requirements

## Karpenter for Node Provisioning

### Why Karpenter?

Karpenter replaces Cluster Autoscaler with a more efficient approach:

**Traditional Cluster Autoscaler**:
1. Pod pending → CA detects
2. CA evaluates node groups
3. CA requests ASG scale-up
4. ASG launches instance (2-5 min)
5. Node joins cluster
6. Pod scheduled

**Karpenter**:
1. Pod pending → Karpenter detects
2. Karpenter provisions node directly (30-60 sec)
3. Pod scheduled immediately

### Key Features

**Just-in-Time Provisioning**:
- Provisions nodes based on pending pod requirements
- Right-sizes instances to workload needs
- Supports any instance type matching requirements

**Advanced Bin Packing**:
- Optimizes resource utilization
- Reduces wasted capacity
- Consolidates underutilized nodes automatically

**Native Spot Support**:
- First-class Spot instance support
- Automatic fallback to On-Demand
- Handles interruptions gracefully

**Flexible Configuration**:
```yaml
# NodePool - defines provisioning policies
spec:
  limits:
    cpu: "100"
    memory: 400Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
```

### Implementation in Infrastructure

**Terraform Module**: `modules/karpenter/`
- Creates Karpenter controller IAM role with Pod Identity
- Deploys Karpenter via Helm
- Configures service account and permissions

**Configuration**: `charts/karpenter-config/`
- NodePool: Defines node provisioning policies
- EC2NodeClass: Specifies AMI, networking, and node configuration

**Enablement** (disabled by default):
```bash
# In tfvars
enable_karpenter = true
karpenter_version = "1.0.1"
```

## Latest Generation Instance Types

### Current Configuration
- **Previous**: m5 (5th gen Intel)
- **Updated**: m7i (7th gen Intel)

### Why m7i?

**Performance**:
- Up to 15% better performance vs m5
- Lower latency for memory-intensive workloads
- Better network performance (up to 50 Gbps)

**Cost Efficiency**:
- Better performance per dollar
- More efficient resource utilization
- Reduced total instance count needed

**Availability**:
- Available in us-east-1 and most major regions
- Full EKS support
- Compatible with AL2023 AMI

### Instance Type Strategy

**Nonprod**:
- m7i.large for general workloads
- Karpenter can provision c7i, m7i, r7i based on needs
- Spot instances enabled for cost savings

**Prod**:
- m7i.xlarge for production workloads
- On-Demand only for stability
- Karpenter can scale to larger sizes when needed

## Amazon Linux 2023 (AL2023)

### Why AL2023?

**Security**:
- 5-year support lifecycle
- Quarterly security updates
- SELinux enabled by default

**Performance**:
- Optimized for AWS infrastructure
- Faster boot times
- Lower memory footprint

**Container Support**:
- Native containerd integration
- Optimized for EKS workloads
- Minimal attack surface

### Implementation
```yaml
# eksctl config
managedNodeGroups:
  - name: dev
    amiFamily: AmazonLinux2023
```

## EKS Managed Add-ons

### Current Add-ons

All clusters include these managed add-ons:

```yaml
addons:
  - name: vpc-cni          # VPC networking
  - name: coredns          # DNS resolution
  - name: kube-proxy       # Service networking
  - name: aws-ebs-csi-driver  # EBS volume support
  - name: eks-pod-identity-agent  # Pod Identity support
```

### Benefits of Managed Add-ons

- **Automatic Updates**: AWS manages version compatibility
- **Security**: CVE patches applied automatically
- **Compatibility**: Tested with EKS versions
- **Reliability**: AWS support and SLA coverage

## GP3 Volumes

### Configuration
```yaml
volumeType: gp3
volumeSize: 50  # nonprod
volumeSize: 100 # prod
```

### Why GP3?

**Cost**:
- 20% cheaper than GP2
- Predictable pricing model

**Performance**:
- 3,000 IOPS baseline (vs 100-16,000 for GP2)
- 125 MB/s throughput baseline
- Independent IOPS and throughput scaling

**Flexibility**:
- Provision IOPS up to 16,000
- Provision throughput up to 1,000 MB/s
- No performance tiers

## Security Best Practices

### Network Security

**Private Subnets Only**:
```yaml
privateNetworking: true
```
- Nodes in private subnets
- No public IP addresses
- NAT Gateway for egress

**Security Group Tags**:
```bash
karpenter.sh/discovery: cluckn-bell-nonprod
```
- Karpenter discovers security groups via tags
- Automatic security group management

### IAM Security

**Least Privilege**:
- Minimal permissions for node IAM roles
- Service-specific IRSA/Pod Identity roles
- No shared credentials

**SSM Access**:
```yaml
attachPolicyARNs:
  - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```
- Secure node access via SSM Session Manager
- No SSH keys required
- Audit logs in CloudWatch

### Encryption

**EBS Encryption**:
```yaml
blockDeviceMappings:
  - deviceName: /dev/xvda
    ebs:
      encrypted: true
```

**Secrets Encryption**:
- KMS encryption for EKS secrets
- Encrypted environment variables

## Cost Optimization

### Karpenter Consolidation

**Automatic Rightsizing**:
```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 1m
```
- Consolidates underutilized nodes
- Reduces wasted capacity
- Lowers compute costs

### Spot Instances (Nonprod)

**Configuration**:
```yaml
- key: karpenter.sh/capacity-type
  operator: In
  values: ["on-demand", "spot"]
```
- Up to 90% cost savings
- Automatic fallback to On-Demand
- Graceful interruption handling

### Instance Selection

**Flexible Instance Types**:
```yaml
- key: karpenter.k8s.aws/instance-category
  operator: In
  values: ["c", "m", "r"]
- key: karpenter.k8s.aws/instance-generation
  operator: Gt
  values: ["6"]
```
- Karpenter selects best price/performance
- Not limited to specific instance types
- Adapts to market prices

## Monitoring and Observability

### CloudWatch Integration

**Control Plane Logging**:
```yaml
cloudWatch:
  clusterLogging:
    enableTypes:
      - api
      - audit
      - authenticator
      - controllerManager
      - scheduler
```

**Retention**:
- Nonprod: 7 days
- Prod: 90 days

### Karpenter Metrics

**CloudWatch Metrics**:
- Node provisioning time
- Instance type distribution
- Cost per workload
- Consolidation savings

## Upgrade Path

### Quarterly Review Cycle

1. **Q1**: Review new Kubernetes versions and EKS features
2. **Q2**: Update nonprod clusters, test workloads
3. **Q3**: Update prod clusters after validation
4. **Q4**: Review costs and optimize

### Component Updates

**Karpenter**:
- Check for new releases monthly
- Review changelog for breaking changes
- Test in nonprod first

**EKS Add-ons**:
- Use `version: latest` for automatic updates
- Monitor release notes for breaking changes
- Pin versions for prod if needed

## Compliance and Governance

### Tagging Strategy

**Required Tags**:
```yaml
tags:
  Project: cluckn-bell
  Environment: nonprod|prod
  ManagedBy: eksctl|karpenter|terraform
  karpenter.sh/discovery: cluckn-bell-{env}
```

### Resource Naming

**Convention**:
- Cluster: `cluckn-bell-{environment}`
- Node groups: `{cluster}-{role}`
- Karpenter nodes: `karpenter-{cluster}-{hash}`

## Summary of Changes

| Component | Previous | Updated | Benefit |
|-----------|----------|---------|---------|
| Kubernetes | 1.34 (invalid) | 1.33 | Modern, stable version |
| Node Provisioning | Cluster Autoscaler | Karpenter | Faster, more efficient |
| IAM Integration | IRSA only | Pod Identity + IRSA | Simplified, automatic |
| Instance Types | m5 | m7i | Better performance/cost |
| Add-ons | Basic | + Pod Identity agent | Enhanced security |
| Volumes | gp2 | gp3 | 20% cost savings |

## Next Steps

1. **Review configurations** in `eksctl/` and `charts/karpenter-config/`
2. **Test in nonprod** before enabling in production
3. **Monitor costs** after enabling Karpenter
4. **Document learnings** for future improvements
5. **Train team** on new tools and practices

## References

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter Documentation](https://karpenter.sh/)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Amazon Linux 2023](https://aws.amazon.com/linux/amazon-linux-2023/)
- [GP3 Volumes](https://aws.amazon.com/ebs/general-purpose/)
