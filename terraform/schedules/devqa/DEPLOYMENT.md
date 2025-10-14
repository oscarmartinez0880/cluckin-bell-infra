# Deployment Guide: EKS Cost Optimization for Dev/QA

This guide provides step-by-step instructions for deploying the EKS cost optimization changes.

## Overview

This deployment includes:
1. **Instance Type Change**: m5.large → t3.medium (dev/qa cluster only)
2. **Automated Scheduler**: Scale nodegroups to 0 during off-hours

## Prerequisites

Before deploying, ensure you have:
- AWS CLI configured with `cluckin-bell-qa` profile
- Terraform >= 1.13.1 installed
- kubectl configured for the dev/qa cluster (optional, for verification)
- Appropriate AWS permissions to:
  - Modify EKS cluster configuration
  - Create Lambda functions
  - Create IAM roles and policies
  - Create EventBridge schedules

## Deployment Steps

### Part 1: Deploy Instance Type Change

The instance type change will be applied when the EKS cluster configuration is next updated. Since this change affects the nodegroup configuration, it will trigger a rolling update of nodes.

```bash
cd terraform/clusters/devqa

# Review the change
terraform plan

# Apply the change
terraform apply

# The change will show:
# - instance_types: ["m5.large"] -> ["t3.medium"]
```

**Note**: The instance type change will cause a rolling update of nodes. Pods will be drained and rescheduled on new t3.medium instances. Plan for a brief disruption during the update.

### Part 2: Deploy the Scheduler

```bash
cd terraform/schedules/devqa

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Expected resources to be created:
# - aws_lambda_function.eks_scaler
# - aws_iam_role.lambda_role
# - aws_iam_role.scheduler_role
# - aws_iam_role_policy.lambda_eks_policy
# - aws_iam_role_policy.scheduler_lambda_policy
# - aws_iam_role_policy_attachment.lambda_logs
# - aws_scheduler_schedule.scale_up
# - aws_scheduler_schedule.scale_down
# - aws_cloudwatch_log_group.lambda_logs
# - data.archive_file.lambda_zip

# Apply the configuration
terraform apply

# Save the outputs
terraform output
```

## Verification

### 1. Verify Lambda Function

```bash
# Check function exists
aws --profile cluckin-bell-qa lambda get-function \
  --function-name cb-devqa-eks-scaler

# View function configuration
aws --profile cluckin-bell-qa lambda get-function-configuration \
  --function-name cb-devqa-eks-scaler
```

### 2. Verify EventBridge Schedules

```bash
# Check scale-up schedule
aws --profile cluckin-bell-qa scheduler get-schedule \
  --name cb-devqa-eks-scale-up

# Check scale-down schedule
aws --profile cluckin-bell-qa scheduler get-schedule \
  --name cb-devqa-eks-scale-down
```

### 3. Verify IAM Permissions

```bash
# Check Lambda execution role
aws --profile cluckin-bell-qa iam get-role \
  --role-name cb-devqa-eks-scaler-role

# Check inline policy
aws --profile cluckin-bell-qa iam get-role-policy \
  --role-name cb-devqa-eks-scaler-role \
  --policy-name eks-scaler-policy
```

### 4. Test Scale Down

```bash
# Manually invoke scale down
aws --profile cluckin-bell-qa lambda invoke \
  --function-name cb-devqa-eks-scaler \
  --payload '{"action":"scale_down"}' \
  response.json

# View response
cat response.json | jq .

# Wait 30 seconds, then check nodegroup
sleep 30
aws --profile cluckin-bell-qa eks describe-nodegroup \
  --cluster-name cb-use1-shared \
  --nodegroup-name default \
  --query 'nodegroup.scalingConfig'

# Expected output:
# {
#     "minSize": 0,
#     "maxSize": 0,
#     "desiredSize": 0
# }

# Check nodes (should start draining)
kubectl get nodes

# After a few minutes, all nodes should be gone
watch kubectl get nodes
```

### 5. Test Scale Up

```bash
# Manually invoke scale up
aws --profile cluckin-bell-qa lambda invoke \
  --function-name cb-devqa-eks-scaler \
  --payload '{"action":"scale_up"}' \
  response.json

# View response
cat response.json | jq .

# Check nodegroup configuration
aws --profile cluckin-bell-qa eks describe-nodegroup \
  --cluster-name cb-use1-shared \
  --nodegroup-name default \
  --query 'nodegroup.scalingConfig'

# Expected output:
# {
#     "minSize": 2,
#     "maxSize": 5,
#     "desiredSize": 2
# }

# Wait 2-3 minutes for nodes to provision
sleep 180

# Check nodes (should see 2 new t3.medium nodes)
kubectl get nodes
kubectl describe nodes | grep "instance-type"
# Should show: beta.kubernetes.io/instance-type=t3.medium
```

### 6. Monitor CloudWatch Logs

```bash
# Tail Lambda logs
aws --profile cluckin-bell-qa logs tail \
  /aws/lambda/cb-devqa-eks-scaler \
  --follow

# Or view recent log streams
aws --profile cluckin-bell-qa logs describe-log-streams \
  --log-group-name /aws/lambda/cb-devqa-eks-scaler \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

## Schedule Behavior

The scheduler operates on the following schedule:

| Day       | Scale Up    | Scale Down  | Hours Active |
|-----------|-------------|-------------|--------------|
| Monday    | 08:00 AM ET | 09:00 PM ET | 13 hours     |
| Tuesday   | 08:00 AM ET | 09:00 PM ET | 13 hours     |
| Wednesday | 08:00 AM ET | 09:00 PM ET | 13 hours     |
| Thursday  | 08:00 AM ET | 09:00 PM ET | 13 hours     |
| Friday    | 08:00 AM ET | 09:00 PM ET | 13 hours     |
| Saturday  | Scaled down | Scaled down | 0 hours      |
| Sunday    | Scaled down | Scaled down | 0 hours      |

**Total**: 65 hours active per week (out of 168) = ~39% uptime

## Rollback Plan

If you need to rollback the changes:

### Rollback Scheduler

```bash
cd terraform/schedules/devqa
terraform destroy

# This will remove:
# - Lambda function
# - EventBridge schedules
# - IAM roles and policies
# - CloudWatch log groups
```

### Rollback Instance Type

```bash
cd terraform/clusters/devqa

# Edit main.tf and change:
# instance_types = ["t3.medium"]
# back to:
# instance_types = ["m5.large"]

terraform plan
terraform apply
```

### Emergency: Manually Restore Capacity

If the scheduler scales down unexpectedly and you need capacity immediately:

```bash
# Option 1: Use the Lambda function
aws --profile cluckin-bell-qa lambda invoke \
  --function-name cb-devqa-eks-scaler \
  --payload '{"action":"scale_up"}' \
  /dev/stdout

# Option 2: Use the AWS CLI directly
aws --profile cluckin-bell-qa eks update-nodegroup-config \
  --cluster-name cb-use1-shared \
  --nodegroup-name default \
  --scaling-config minSize=2,maxSize=5,desiredSize=2

# Option 3: Use the AWS Console
# Navigate to EKS -> Clusters -> cb-use1-shared -> Compute -> default
# Click "Edit" and update the scaling configuration
```

## Monitoring

### Daily Checks (First Week)

For the first week after deployment, monitor:

1. **Schedule execution**:
   ```bash
   aws --profile cluckin-bell-qa logs filter-log-events \
     --log-group-name /aws/lambda/cb-devqa-eks-scaler \
     --start-time $(date -d "1 day ago" +%s)000
   ```

2. **Node status** at 8:30 AM and 9:30 PM ET:
   ```bash
   kubectl get nodes
   ```

3. **Application health** after scale-up:
   ```bash
   kubectl get pods --all-namespaces
   ```

### Alerts (Recommended)

Consider setting up CloudWatch alarms for:
- Lambda function errors
- Lambda function throttles
- Nodegroup scaling failures

## Customization

### Change Schedule

To adjust the scale-up/down times, edit `terraform/schedules/devqa/variables.tf`:

```hcl
variable "scale_up_cron" {
  default = "cron(0 7 ? * MON-FRI *)"  # Change to 7 AM
}

variable "scale_down_cron" {
  default = "cron(0 22 ? * MON-FRI *)"  # Change to 10 PM
}
```

Then apply:
```bash
cd terraform/schedules/devqa
terraform apply
```

### Change Capacity

To adjust the daytime or off-hours capacity:

```hcl
variable "scale_up_desired_size" {
  default = 3  # Increase to 3 nodes during the day
}
```

### Add Weekend Hours

To enable the cluster on weekends, modify the cron expressions:

```hcl
variable "scale_up_cron" {
  default = "cron(0 8 ? * * *)"  # Every day including weekends
}

variable "scale_down_cron" {
  default = "cron(0 21 ? * * *)"  # Every day including weekends
}
```

## Cost Tracking

Monitor your cost savings using AWS Cost Explorer:

1. Navigate to AWS Cost Explorer
2. Filter by Service: "Amazon Elastic Kubernetes Service" and "Amazon EC2"
3. Group by: Resource
4. Compare costs before and after deployment

Expected savings:
- **Compute hours**: 61% reduction (103 hours/week saved)
- **Per-hour cost**: ~40% reduction (t3.medium vs m5.large)
- **Combined**: ~76% reduction in EC2 compute costs

## Troubleshooting

See [README.md](README.md#troubleshooting) for detailed troubleshooting steps.

## Support

For issues or questions:
1. Check CloudWatch Logs: `/aws/lambda/cb-devqa-eks-scaler`
2. Review [README.md](README.md) for common issues
3. Contact the infrastructure team

## References

- [Main README](README.md)
- [Terraform AWS EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [EventBridge Scheduler](https://docs.aws.amazon.com/scheduler/latest/UserGuide/what-is-scheduler.html)
- [EKS UpdateNodegroupConfig API](https://docs.aws.amazon.com/eks/latest/APIReference/API_UpdateNodegroupConfig.html)
