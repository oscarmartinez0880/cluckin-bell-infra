# On-Demand EKS Cluster Lifecycle - Testing Guide

This guide provides detailed testing instructions for the on-demand EKS cluster lifecycle controls.

## Overview

The on-demand lifecycle controls allow you to:
- **Start clusters** using `make cluster-up-qa` or `make cluster-up-prod`
- **Stop clusters** using `make cluster-down-qa` or `make cluster-down-prod`
- **Minimize costs** by completely deleting clusters when not in use

## Prerequisites

Before testing, ensure you have:

1. **AWS CLI** with SSO configured
   ```bash
   aws --version  # Should be v2.x or higher
   ```

2. **eksctl** installed
   ```bash
   eksctl version  # Should be v0.150.0 or higher
   ```

3. **kubectl** installed
   ```bash
   kubectl version --client
   ```

4. **AWS SSO profiles** configured in `~/.aws/config`:
   - `cluckin-bell-qa` (account 264765154707)
   - `cluckin-bell-prod` (account 346746763840)

5. **VPC infrastructure** already deployed via Terraform
   - The eksctl configs reference existing VPC IDs and subnet IDs
   - Ensure these are created before attempting cluster creation

## Test Plan

### Test 1: Nonprod Cluster Lifecycle (QA)

**Objective:** Verify that the nonprod cluster can be created and destroyed on-demand.

**Steps:**

1. **Ensure SSO Login**
   ```bash
   aws sso login --profile cluckin-bell-qa
   ```

2. **Verify Authentication**
   ```bash
   aws sts get-caller-identity --profile cluckin-bell-qa
   ```
   
   **Expected Output:**
   ```json
   {
       "UserId": "...",
       "Account": "264765154707",
       "Arn": "arn:aws:sts::264765154707:..."
   }
   ```

3. **Create Nonprod Cluster**
   ```bash
   make cluster-up-qa
   ```
   
   **Expected Behavior:**
   - Script checks for existing cluster
   - If not exists, runs `eksctl create cluster` with config from `eksctl/devqa-cluster.yaml`
   - Creates cluster with name `cluckn-bell-nonprod`
   - Creates 2 node groups: `dev` and `qa`
   - Takes approximately 15-20 minutes
   
   **Expected Output (end of creation):**
   ```
   [INFO] ==========================================
   [INFO] Cluster Created Successfully!
   [INFO] ==========================================
   ```

4. **Verify Cluster Exists**
   ```bash
   aws eks describe-cluster \
     --name cluckn-bell-nonprod \
     --region us-east-1 \
     --profile cluckin-bell-qa \
     --query 'cluster.{Name:name,Status:status,Version:version,Endpoint:endpoint}'
   ```
   
   **Expected Output:**
   ```json
   {
       "Name": "cluckn-bell-nonprod",
       "Status": "ACTIVE",
       "Version": "1.30",
       "Endpoint": "https://..."
   }
   ```

5. **Verify Node Groups**
   ```bash
   aws eks list-nodegroups \
     --cluster-name cluckn-bell-nonprod \
     --region us-east-1 \
     --profile cluckin-bell-qa
   ```
   
   **Expected Output:**
   ```json
   {
       "nodegroups": [
           "dev",
           "qa"
       ]
   }
   ```

6. **Verify Node Configuration**
   ```bash
   aws eks describe-nodegroup \
     --cluster-name cluckn-bell-nonprod \
     --nodegroup-name dev \
     --region us-east-1 \
     --profile cluckin-bell-qa \
     --query 'nodegroup.{Name:nodegroupName,InstanceTypes:instanceTypes,ScalingConfig:scalingConfig}'
   ```
   
   **Expected Output:**
   ```json
   {
       "Name": "dev",
       "InstanceTypes": ["t3.small"],
       "ScalingConfig": {
           "minSize": 0,
           "maxSize": 2,
           "desiredSize": 1
       }
   }
   ```

7. **Update Kubeconfig and Access Cluster**
   ```bash
   aws eks update-kubeconfig \
     --name cluckn-bell-nonprod \
     --region us-east-1 \
     --profile cluckin-bell-qa
   
   kubectl get nodes
   ```
   
   **Expected Output:**
   ```
   NAME                             STATUS   ROLES    AGE   VERSION
   ip-10-60-1-xxx.ec2.internal      Ready    <none>   5m    v1.30.x
   ip-10-60-2-xxx.ec2.internal      Ready    <none>   5m    v1.30.x
   ```

8. **Verify Node Labels**
   ```bash
   kubectl get nodes --show-labels | grep environment
   ```
   
   **Expected Output:**
   - One node with `environment=dev`
   - One node with `environment=qa`

9. **Test Idempotency (Run cluster-up-qa Again)**
   ```bash
   make cluster-up-qa
   ```
   
   **Expected Behavior:**
   - Script detects cluster already exists
   - Displays current status
   - Exits without error
   - Does NOT create a duplicate cluster
   
   **Expected Output:**
   ```
   [WARN] Cluster cluckn-bell-nonprod already exists!
   [INFO] If you want to upgrade or modify it, use:
   ```

10. **Delete Nonprod Cluster**
    ```bash
    make cluster-down-qa
    ```
    
    **Expected Behavior:**
    - Script prompts for confirmation: "Are you sure you want to delete this cluster? (yes/no):"
    - Enter `yes` to proceed
    - Runs `eksctl delete cluster`
    - Takes approximately 10-15 minutes
    
    **Expected Output (end of deletion):**
    ```
    [INFO] ==========================================
    [INFO] Cluster Deleted Successfully!
    [INFO] ==========================================
    ```

11. **Verify Cluster is Deleted**
    ```bash
    aws eks describe-cluster \
      --name cluckn-bell-nonprod \
      --region us-east-1 \
      --profile cluckin-bell-qa
    ```
    
    **Expected Output:**
    ```
    An error occurred (ResourceNotFoundException) when calling the DescribeCluster operation: No cluster found for name: cluckn-bell-nonprod.
    ```
    
    This error is CORRECT - it confirms the cluster is deleted.

12. **Test Deletion Idempotency**
    ```bash
    make cluster-down-qa
    ```
    
    **Expected Behavior:**
    - Script detects cluster doesn't exist
    - Displays message and exits gracefully
    
    **Expected Output:**
    ```
    [WARN] Cluster cluckn-bell-nonprod does not exist or is already deleted.
    [INFO] Nothing to do.
    ```

### Test 2: Prod Cluster Lifecycle

**Objective:** Verify that the prod cluster can be created and destroyed on-demand.

**Steps:**

1. **Ensure SSO Login**
   ```bash
   aws sso login --profile cluckin-bell-prod
   ```

2. **Verify Authentication**
   ```bash
   aws sts get-caller-identity --profile cluckin-bell-prod
   ```
   
   **Expected Output:**
   ```json
   {
       "UserId": "...",
       "Account": "346746763840",
       "Arn": "arn:aws:sts::346746763840:..."
   }
   ```

3. **Create Prod Cluster**
   ```bash
   make cluster-up-prod
   ```
   
   **Expected Behavior:**
   - Creates cluster with name `cluckn-bell-prod`
   - Creates 1 node group: `prod`
   - Takes approximately 15-20 minutes

4. **Verify Cluster Configuration**
   ```bash
   aws eks describe-nodegroup \
     --cluster-name cluckn-bell-prod \
     --nodegroup-name prod \
     --region us-east-1 \
     --profile cluckin-bell-prod \
     --query 'nodegroup.{Name:nodegroupName,InstanceTypes:instanceTypes,ScalingConfig:scalingConfig}'
   ```
   
   **Expected Output:**
   ```json
   {
       "Name": "prod",
       "InstanceTypes": ["t3.medium"],
       "ScalingConfig": {
           "minSize": 1,
           "maxSize": 5,
           "desiredSize": 2
       }
   }
   ```

5. **Access Cluster**
   ```bash
   aws eks update-kubeconfig \
     --name cluckn-bell-prod \
     --region us-east-1 \
     --profile cluckin-bell-prod
   
   kubectl get nodes
   ```
   
   **Expected Output:**
   ```
   NAME                             STATUS   ROLES    AGE   VERSION
   ip-10-70-1-xxx.ec2.internal      Ready    <none>   5m    v1.30.x
   ip-10-70-2-xxx.ec2.internal      Ready    <none>   5m    v1.30.x
   ```

6. **Delete Prod Cluster**
   ```bash
   make cluster-down-prod
   ```
   
   **Expected Behavior:**
   - Prompts for confirmation
   - Enter `yes` to proceed
   - Deletes cluster successfully

7. **Verify Deletion**
   ```bash
   aws eks describe-cluster \
     --name cluckn-bell-prod \
     --region us-east-1 \
     --profile cluckin-bell-prod
   ```
   
   **Expected Output:**
   ```
   An error occurred (ResourceNotFoundException)...
   ```

### Test 3: Direct Script Usage

**Objective:** Verify the `manage-cluster.sh` script works correctly when called directly.

**Steps:**

1. **Test Script Help**
   ```bash
   ./scripts/manage-cluster.sh
   ```
   
   **Expected Output:**
   ```
   Usage: ./scripts/manage-cluster.sh <action> <environment>
   
   Actions:
     up      Create/start the EKS cluster
     down    Delete/stop the EKS cluster
   
   Environments:
     dev     Development environment...
     qa      QA environment...
     prod    Production environment...
   ```

2. **Test Script with Dev Environment**
   ```bash
   aws sso login --profile cluckin-bell-qa
   ./scripts/manage-cluster.sh up dev
   ```
   
   **Expected Behavior:**
   - Maps `dev` to nonprod cluster (`cluckn-bell-nonprod`)
   - Uses profile `cluckin-bell-qa`
   - Creates cluster (or reports it already exists)

3. **Test Invalid Arguments**
   ```bash
   ./scripts/manage-cluster.sh invalid-action qa
   ```
   
   **Expected Output:**
   ```
   [ERROR] Invalid action: invalid-action
   Usage: ...
   ```

4. **Test Deletion Cancellation**
   ```bash
   ./scripts/manage-cluster.sh down qa
   # When prompted "Are you sure...?", type "no" and press Enter
   ```
   
   **Expected Behavior:**
   - Script prompts for confirmation
   - Entering anything other than "yes" cancels deletion
   - Script exits without deleting cluster

### Test 4: Cost Verification

**Objective:** Verify that costs are minimized when clusters are deleted.

**Steps:**

1. **Check Costs Before Cluster Creation**
   - Navigate to AWS Cost Explorer for account 264765154707
   - Note current daily EKS costs (should be $0 if no cluster exists)

2. **Create Cluster**
   ```bash
   make cluster-up-qa
   ```

3. **Wait 24 Hours and Check Costs**
   - Return to AWS Cost Explorer
   - Verify EKS costs appear (~$2-3/day for control plane + ~$1-2/day for 2x t3.small nodes)

4. **Delete Cluster**
   ```bash
   make cluster-down-qa
   ```

5. **Wait 24 Hours and Check Costs**
   - Return to AWS Cost Explorer
   - Verify EKS costs return to $0
   - VPC costs remain minimal (~$0.10-0.30/day for NAT gateway if enabled)

## Expected Results Summary

| Test | Expected Result |
|------|----------------|
| Nonprod cluster creation | Cluster created in ~15-20 min, 2 node groups (dev, qa), t3.small instances |
| Nonprod cluster access | kubectl can connect, 2 nodes visible with correct labels |
| Nonprod cluster idempotency | Re-running cluster-up-qa safely detects existing cluster |
| Nonprod cluster deletion | Cluster deleted in ~10-15 min, confirmation required |
| Nonprod deletion idempotency | Re-running cluster-down-qa safely reports "already deleted" |
| Prod cluster creation | Cluster created in ~15-20 min, 1 node group (prod), t3.medium instances |
| Prod cluster access | kubectl can connect, 2 nodes visible |
| Prod cluster deletion | Cluster deleted in ~10-15 min, confirmation required |
| Script direct usage | Works for dev/qa/prod, proper error handling |
| Cost minimization | $0 EKS costs when cluster deleted |

## Troubleshooting

### Issue: "eksctl not found"

**Solution:**
```bash
# macOS
brew install eksctl

# Linux
curl --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

### Issue: "Cannot authenticate with AWS profile"

**Solution:**
```bash
# Re-login to AWS SSO
aws sso login --profile cluckin-bell-qa

# Verify credentials
aws sts get-caller-identity --profile cluckin-bell-qa
```

### Issue: "VPC ID placeholder detected"

**Cause:** The eksctl config file still contains placeholder VPC/subnet IDs.

**Solution:**
```bash
# Get VPC outputs from Terraform
cd terraform/clusters/devqa
terraform output

# Update eksctl/devqa-cluster.yaml or eksctl/prod-cluster.yaml
# Replace vpc-REPLACE_WITH_VPC_ID with actual VPC ID
# Replace subnet-REPLACE_WITH_SUBNET_* with actual subnet IDs
```

### Issue: Cluster creation fails with "InvalidSubnetID.NotFound"

**Cause:** VPC and subnets don't exist yet.

**Solution:**
```bash
# Deploy VPC infrastructure first
make vpc

# Then create cluster
make cluster-up-qa
```

### Issue: "Cluster already exists" but I want to upgrade

**Solution:**
```bash
# Option 1: Delete and recreate
make cluster-down-qa
make cluster-up-qa

# Option 2: Use eksctl upgrade directly
eksctl upgrade cluster \
  --config-file=eksctl/devqa-cluster.yaml \
  --profile=cluckin-bell-qa \
  --approve
```

## Cleanup After Testing

After testing is complete, ensure all clusters are deleted to minimize costs:

```bash
# Delete nonprod cluster
make cluster-down-qa

# Delete prod cluster  
make cluster-down-prod

# Verify all clusters deleted
aws eks list-clusters --region us-east-1 --profile cluckin-bell-qa
aws eks list-clusters --region us-east-1 --profile cluckin-bell-prod
```

Both commands should return empty lists:
```json
{
    "clusters": []
}
```
