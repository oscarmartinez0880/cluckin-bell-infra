# Karpenter Migration Guide

This guide explains how to migrate from Cluster Autoscaler to Karpenter for node provisioning in your EKS clusters.

## Overview

Karpenter is a flexible, high-performance Kubernetes cluster autoscaler that replaces the legacy Cluster Autoscaler approach with just-in-time node provisioning.

### Benefits of Karpenter

| Feature | Cluster Autoscaler | Karpenter |
|---------|-------------------|-----------|
| **Provisioning Speed** | 3-5 minutes | 30-60 seconds |
| **Instance Selection** | Limited by node group types | Any instance type matching requirements |
| **Bin Packing** | Basic | Advanced with pod-level awareness |
| **Spot Support** | Limited | Native with automatic fallback |
| **Disruption Handling** | Manual | Automated consolidation |
| **Configuration** | Per node group | Cluster-wide policies |

## Prerequisites

Before starting the migration:

1. **EKS Cluster Version**: Must be running Kubernetes 1.33 or newer
2. **eks-pod-identity-agent**: Must be installed (included in updated eksctl configs)
3. **Node IAM Role**: Existing node IAM role must be available
4. **Subnet and SG Tags**: Subnets and security groups must be tagged for Karpenter discovery

## Migration Steps

### Step 1: Update EKS Cluster Configuration

If your cluster is not yet on Kubernetes 1.33, upgrade first:

```bash
# Backup current cluster configuration
eksctl get cluster --name cluckn-bell-nonprod -o yaml > cluster-backup.yaml

# Update cluster version in eksctl config
# Edit eksctl/devqa-cluster.yaml or eksctl/prod-cluster.yaml
# Change version to "1.33"

# Upgrade cluster control plane
eksctl upgrade cluster --config-file=eksctl/devqa-cluster.yaml --approve

# Upgrade node groups
eksctl upgrade nodegroup --config-file=eksctl/devqa-cluster.yaml --approve
```

### Step 2: Tag Existing Resources for Karpenter Discovery

Karpenter uses tags to discover resources. Add the following tags:

**Subnets** (both public and private):
```bash
# For nonprod cluster
aws ec2 create-tags --resources subnet-xxx subnet-yyy subnet-zzz \
  --tags Key=karpenter.sh/discovery,Value=cluckn-bell-nonprod

# For prod cluster
aws ec2 create-tags --resources subnet-xxx subnet-yyy subnet-zzz \
  --tags Key=karpenter.sh/discovery,Value=cluckn-bell-prod
```

**Security Groups** (node security group):
```bash
# For nonprod cluster
aws ec2 create-tags --resources sg-xxxxxxxx \
  --tags Key=karpenter.sh/discovery,Value=cluckn-bell-nonprod

# For prod cluster
aws ec2 create-tags --resources sg-xxxxxxxx \
  --tags Key=karpenter.sh/discovery,Value=cluckn-bell-prod
```

### Step 3: Enable Karpenter in Terraform

Update your environment variables to enable Karpenter:

```bash
# Edit envs/nonprod/nonprod.auto.tfvars or envs/prod/prod.auto.tfvars
# Add:
enable_karpenter = true
karpenter_version = "1.0.1"
karpenter_namespace = "kube-system"
```

Apply the Terraform changes:

```bash
cd envs/nonprod  # or envs/prod
terraform init
terraform plan
terraform apply
```

This will:
- Create Karpenter controller IAM role with Pod Identity
- Deploy Karpenter via Helm
- Configure the Karpenter service account

### Step 4: Update NodePool Configuration

Update the NodePool and EC2NodeClass files with your specific cluster details:

```bash
# Edit charts/karpenter-config/nonprod/ec2nodeclass.yaml
# Update the 'role' field with your actual node IAM role name:
role: "cluckn-bell-nonprod-node-role"  # Update this

# For prod
# Edit charts/karpenter-config/prod/ec2nodeclass.yaml
role: "cluckn-bell-prod-node-role"  # Update this
```

To find your node IAM role name:

```bash
# For nonprod
aws iam list-roles | grep cluckn-bell-nonprod.*node

# For prod
aws iam list-roles | grep cluckn-bell-prod.*node
```

### Step 5: Apply Karpenter Configuration

Apply the NodePool and EC2NodeClass to your cluster:

```bash
# For nonprod
kubectl apply -f charts/karpenter-config/nonprod/

# For prod
kubectl apply -f charts/karpenter-config/prod/
```

Verify Karpenter is running:

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# karpenter-xxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### Step 6: Test Karpenter Provisioning

Create a test deployment to verify Karpenter can provision nodes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: karpenter-test
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: karpenter-test
  template:
    metadata:
      labels:
        app: karpenter-test
    spec:
      containers:
      - name: pause
        image: registry.k8s.io/pause:3.9
        resources:
          requests:
            cpu: 1
            memory: 1Gi
```

Apply and watch Karpenter provision nodes:

```bash
kubectl apply -f karpenter-test.yaml

# Watch Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f

# Watch for new nodes
kubectl get nodes -w
```

You should see Karpenter provision new nodes within 30-60 seconds.

### Step 7: Gradual Migration

Once Karpenter is working, gradually migrate workloads:

1. **Add node affinity** to new workloads to prefer Karpenter-provisioned nodes:
   ```yaml
   affinity:
     nodeAffinity:
       preferredDuringSchedulingIgnoredDuringExecution:
       - weight: 100
         preference:
           matchExpressions:
           - key: karpenter.sh/nodepool
             operator: Exists
   ```

2. **Scale down Cluster Autoscaler-managed node groups** gradually:
   ```bash
   # For nonprod dev node group
   eksctl scale nodegroup --cluster=cluckn-bell-nonprod --name=dev --nodes=1
   
   # For nonprod qa node group
   eksctl scale nodegroup --cluster=cluckn-bell-nonprod --name=qa --nodes=2
   ```

3. **Monitor both systems** running in parallel for 1-2 weeks

4. **Verify workload stability** before proceeding

### Step 8: Remove Cluster Autoscaler (Optional)

Once you're confident in Karpenter:

1. **Remove Cluster Autoscaler deployment**:
   ```bash
   kubectl delete deployment cluster-autoscaler -n kube-system
   ```

2. **Remove Cluster Autoscaler IRSA role**:
   ```bash
   # Comment out or remove cluster-autoscaler IRSA module in main.tf
   # Then apply:
   cd envs/nonprod
   terraform apply
   ```

3. **Remove cluster-autoscaler tags** from node groups:
   ```bash
   # Edit eksctl config files
   # Remove these tags:
   # k8s.io/cluster-autoscaler/enabled: "true"
   # k8s.io/cluster-autoscaler/cluckn-bell-nonprod: "owned"
   
   # Update node groups
   eksctl upgrade nodegroup --config-file=eksctl/devqa-cluster.yaml
   ```

## Rollback Procedure

If you need to rollback to Cluster Autoscaler:

1. **Redeploy Cluster Autoscaler**:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
   ```

2. **Scale up original node groups**:
   ```bash
   eksctl scale nodegroup --cluster=cluckn-bell-nonprod --name=dev --nodes=2
   eksctl scale nodegroup --cluster=cluckn-bell-nonprod --name=qa --nodes=3
   ```

3. **Disable Karpenter** in Terraform:
   ```bash
   # Set enable_karpenter = false
   terraform apply
   ```

4. **Delete Karpenter-provisioned nodes**:
   ```bash
   kubectl delete nodepool default
   kubectl delete ec2nodeclass default
   ```

## Monitoring and Troubleshooting

### Check Karpenter Status

```bash
# View Karpenter logs
kubectl logs -n kube-system -l app.kubernetes.io/name=karpenter -f

# Check NodePool status
kubectl get nodepool

# Check EC2NodeClass status
kubectl get ec2nodeclass

# View Karpenter-provisioned nodes
kubectl get nodes -l karpenter.sh/nodepool=default
```

### Common Issues

**Issue**: Karpenter not provisioning nodes
- **Check**: NodePool and EC2NodeClass applied correctly
- **Check**: IAM role has correct permissions
- **Check**: Subnets and security groups are tagged
- **Check**: Pod Identity association is created

**Issue**: Nodes stuck in NotReady state
- **Check**: VPC CNI plugin is working
- **Check**: Node has network connectivity
- **Check**: Security groups allow node-to-control-plane communication

**Issue**: Pods not scheduled on Karpenter nodes
- **Check**: NodePool requirements match pod requirements
- **Check**: Taints and tolerations are correct
- **Check**: Resource requests are within NodePool limits

## Best Practices

1. **Start with nonprod**: Test Karpenter thoroughly in nonprod before prod
2. **Use NodePool limits**: Set reasonable CPU/memory limits to prevent runaway costs
3. **Enable consolidation**: Let Karpenter consolidate underutilized nodes
4. **Monitor costs**: Track instance types and costs with AWS Cost Explorer
5. **Use Spot instances**: Configure Spot in nonprod for cost savings
6. **Set budgets**: Use disruption budgets to limit node churn
7. **Tag everything**: Proper tagging helps with cost allocation and management

## Additional Resources

- [Karpenter Documentation](https://karpenter.sh/)
- [Karpenter Best Practices](https://aws.github.io/aws-eks-best-practices/karpenter/)
- [EKS Pod Identity Documentation](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [Cluster Autoscaler to Karpenter Migration](https://karpenter.sh/docs/getting-started/migrating-from-cas/)
