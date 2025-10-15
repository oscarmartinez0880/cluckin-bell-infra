# EKS Nodegroup Scheduler for Dev/QA

This Terraform module creates a serverless scheduler to automatically scale EKS managed nodegroups up and down on a schedule. This helps reduce costs by scaling down the dev/qa environment during off-hours (nights and weekends).

## Overview

The module provisions:
- **Lambda Function**: Python 3.12 function that scales EKS nodegroups via the AWS API
- **IAM Roles & Policies**: Least-privilege permissions for Lambda and EventBridge Scheduler
- **EventBridge Schedules**: Two schedules to scale up (mornings) and down (nights) on weekdays
- **CloudWatch Logs**: Lambda execution logs with 7-day retention

## Default Configuration

- **Target Cluster**: `cluckn-bell-nonprod` (account 264765154707, us-east-1)
- **Nodegroups**: Auto-discovers all managed nodegroups (empty list = discover all)
- **Scale Up**: Monday-Friday at 08:00 AM ET (`cron(0 8 ? * MON-FRI *)`)
  - min_size=1, desired_size=1, max_size=1
- **Scale Down**: Monday-Friday at 09:00 PM ET (`cron(0 21 ? * MON-FRI *)`)
  - min_size=0, desired_size=0, max_size=1 (EKS requires max >= 1)

Weekends (Saturday-Sunday) remain scaled down.

## Architecture

```
EventBridge Scheduler -> Lambda Function -> EKS API (UpdateNodegroupConfig)
                                    |
                                    v
                            CloudWatch Logs
```

## Usage

### Prerequisites

- AWS CLI configured with `cluckin-bell-qa` profile
- Terraform >= 1.13.1
- EKS cluster `cluckn-bell-nonprod` must exist in the dev/qa account (264765154707)

### Deploy the Scheduler

```bash
cd terraform/schedules/devqa

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### Variables

All variables have sensible defaults. You can override them in a `terraform.tfvars` file or via command line:

```hcl
# terraform.tfvars example
region       = "us-east-1"
profile      = "cluckin-bell-qa"
cluster_name = "cluckn-bell-nonprod"
nodegroups   = []  # Empty list = auto-discover all nodegroups

# Customize daytime capacity
scale_up_min_size     = 1
scale_up_desired_size = 1
scale_up_max_size     = 1

# Customize off-hours capacity (max must be >= 1 for EKS)
scale_down_min_size     = 0
scale_down_desired_size = 0
scale_down_max_size     = 1

# Customize schedule (EventBridge cron format)
scale_up_cron   = "cron(0 8 ? * MON-FRI *)"   # 8 AM ET weekdays
scale_down_cron = "cron(0 21 ? * MON-FRI *)"  # 9 PM ET weekdays
timezone        = "America/New_York"
```

### Auto-Discovery vs Explicit Nodegroups

By default, the Lambda function auto-discovers all managed nodegroups in the cluster:
- Set `nodegroups = []` (or omit it) to scale **all** managed nodegroups
- Set `nodegroups = ["nodegroup1", "nodegroup2"]` to scale only specific nodegroups

You can also override at runtime via the Lambda payload:
```bash
# Auto-discover and scale all nodegroups
aws lambda invoke --payload '{"action":"scale_down"}' ...

# Scale specific nodegroups only
aws lambda invoke --payload '{"action":"scale_down","nodegroups":["ng-1","ng-2"]}' ...
```

## Manual Triggering

### Using AWS CLI

**Scale down** (e.g., for maintenance or cost savings):
```bash
aws --profile cluckin-bell-qa lambda invoke \
  --function-name cb-devqa-eks-scaler \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"scale_down"}' \
  /dev/stdout
```

**Scale up** (e.g., to restore capacity):
```bash
aws --profile cluckin-bell-qa lambda invoke \
  --function-name cb-devqa-eks-scaler \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"scale_up"}' \
  /dev/stdout
```

**Custom scaling** (override defaults):
```bash
aws --profile cluckin-bell-qa lambda invoke \
  --function-name cb-devqa-eks-scaler \
  --cli-binary-format raw-in-base64-out \
  --payload '{
    "action": "scale_up",
    "cluster_name": "cluckn-bell-nonprod",
    "nodegroups": ["nodegroup-1", "nodegroup-2"],
    "wait_for_active": false
  }' \
  /dev/stdout
```

### Using GitHub Actions

You can add a manual workflow dispatch trigger to invoke the Lambda function. Create `.github/workflows/eks-scaler.yml`:

```yaml
name: EKS Dev/QA Manual Scaler

on:
  workflow_dispatch:
    inputs:
      action:
        description: 'Action to perform'
        required: true
        type: choice
        options:
          - scale_up
          - scale_down

permissions:
  id-token: write
  contents: read

jobs:
  scale-eks:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::264765154707:role/github-actions-eks-scaler
          aws-region: us-east-1

      - name: Invoke Lambda Scaler
        run: |
          aws lambda invoke \
            --function-name cb-devqa-eks-scaler \
            --payload "{\"action\":\"${{ github.event.inputs.action }}\"}" \
            response.json
          cat response.json
```

**Note**: You'll need to create an IAM role `github-actions-eks-scaler` with OIDC trust for your GitHub repository and `lambda:InvokeFunction` permission on the scaler Lambda function.

## Verification

After applying, verify the resources:

### Check Lambda Function
```bash
aws --profile cluckin-bell-qa lambda get-function \
  --function-name cb-devqa-eks-scaler
```

### Check EventBridge Schedules
```bash
aws --profile cluckin-bell-qa scheduler get-schedule \
  --name cb-devqa-eks-scale-up

aws --profile cluckin-bell-qa scheduler get-schedule \
  --name cb-devqa-eks-scale-down
```

### Check Current Nodegroup Configuration
```bash
# List all nodegroups
aws --profile cluckin-bell-qa eks list-nodegroups \
  --cluster-name cluckn-bell-nonprod

# Check specific nodegroup scaling config
aws --profile cluckin-bell-qa eks describe-nodegroup \
  --cluster-name cluckn-bell-nonprod \
  --nodegroup-name <nodegroup-name> \
  --query 'nodegroup.scalingConfig'
```

### Check Running Nodes
```bash
kubectl get nodes
```

After scaling down, nodes should drain and terminate. After scaling up, new nodes should be provisioned.

## Testing

### Test Scale Down
```bash
# Manually invoke scale down
aws --profile cluckin-bell-qa lambda invoke \
  --function-name cb-devqa-eks-scaler \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"scale_down"}' \
  /dev/stdout

# Wait 30 seconds, then check nodes
sleep 30
kubectl get nodes
```

### Test Scale Up
```bash
# Manually invoke scale up
aws --profile cluckin-bell-qa lambda invoke \
  --function-name cb-devqa-eks-scaler \
  --cli-binary-format raw-in-base64-out \
  --payload '{"action":"scale_up"}' \
  /dev/stdout

# Wait 2-3 minutes for nodes to come up
sleep 180
kubectl get nodes
```

## CloudWatch Logs

Lambda execution logs are available in CloudWatch:

```bash
aws --profile cluckin-bell-qa logs tail \
  /aws/lambda/cb-devqa-eks-scaler \
  --follow
```

## Cost Savings

With the default schedule, the dev/qa cluster is:
- **Active**: Monday-Friday 8 AM - 9 PM ET (13 hours/day × 5 days = 65 hours/week)
- **Scaled Down**: Nights and weekends (168 - 65 = 103 hours/week)

**Estimated savings**: ~61% reduction in EC2 compute costs (103/168 hours)

Switching from m5.large to t3.medium provides additional per-hour savings.

## Customization

### Adjust Schedule

To change when nodes scale up/down, modify `scale_up_cron` and `scale_down_cron` variables.

EventBridge cron format: `cron(Minutes Hours Day-of-month Month Day-of-week Year)`

Examples:
- `cron(0 7 ? * MON-FRI *)` - 7 AM weekdays
- `cron(0 22 ? * MON-FRI *)` - 10 PM weekdays
- `cron(0 9 ? * * *)` - 9 AM every day (including weekends)

### Multiple Nodegroups

By default, the scheduler auto-discovers and scales **all** managed nodegroups. To scale only specific nodegroups:

```hcl
nodegroups = ["nodegroup-1", "nodegroup-2"]
```

Or override via `-var`:
```bash
terraform apply -var='nodegroups=["nodegroup-1"]'
```

## Troubleshooting

### Lambda Execution Errors

Check CloudWatch Logs for detailed error messages:
```bash
aws --profile cluckin-bell-qa logs tail /aws/lambda/cb-devqa-eks-scaler --follow
```

### Nodegroup Not Scaling

Verify IAM permissions:
```bash
aws --profile cluckin-bell-qa iam get-role-policy \
  --role-name cb-devqa-eks-scaler-role \
  --policy-name eks-scaler-policy
```

### Schedule Not Triggering

Check EventBridge schedule status:
```bash
aws --profile cluckin-bell-qa scheduler get-schedule \
  --name cb-devqa-eks-scale-up
```

## Cleanup

To remove the scheduler and all associated resources:

```bash
cd terraform/schedules/devqa
terraform destroy
```

**Note**: This does not affect the EKS cluster itself, only the scheduler resources.

## Outputs

After applying, Terraform outputs useful information:

- `lambda_function_name`: Name of the Lambda function
- `lambda_function_arn`: ARN of the Lambda function
- `scale_up_schedule_arn`: ARN of the scale-up schedule
- `scale_down_schedule_arn`: ARN of the scale-down schedule
- `manual_invoke_command`: AWS CLI command to manually invoke the function

## References

- [EKS UpdateNodegroupConfig API](https://docs.aws.amazon.com/eks/latest/APIReference/API_UpdateNodegroupConfig.html)
- [EventBridge Scheduler](https://docs.aws.amazon.com/scheduler/latest/UserGuide/what-is-scheduler.html)
- [Lambda Python Runtime](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
