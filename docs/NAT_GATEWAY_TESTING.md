# NAT Gateway Testing Guide

This document provides testing procedures to verify that the NAT gateway provisioning for reused VPCs works correctly in the nonprod environment.

## Overview

The NAT gateway feature (`envs/nonprod/nat.tf`) automatically provisions a NAT gateway and configures private subnet routing when reusing an existing VPC. This ensures EKS nodes in private subnets can reach the internet for:
- Joining the EKS cluster (reaching the public API endpoint)
- Pulling container images from public registries
- Accessing AWS services

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform 1.13.1 or later installed
- Access to the nonprod AWS account (cluckin-bell-qa profile)
- Existing VPC with public and private subnets

## Test Scenarios

### Test 1: Verify Terraform Configuration Validation

Ensure the Terraform configuration is syntactically correct:

```bash
cd envs/nonprod
terraform init -backend=false
terraform validate
```

**Expected Result:** `Success! The configuration is valid.`

### Test 2: Verify NAT Gateway Resource Creation (Dry Run)

Test that Terraform would create the NAT gateway resources when `manage_nat_for_existing_vpc = true`:

```bash
cd envs/nonprod

# Create a test tfvars file (replace VPC and subnet IDs with your actual values)
cat > test-nat.tfvars <<EOF
environment                 = "devqa"
existing_vpc_id            = "vpc-xxxxxxxxxxxxxxxxx"  # Replace with your VPC ID
public_subnet_ids          = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy", "subnet-zzzzzzzzzzzzzzzzz"]
private_subnet_ids         = ["subnet-aaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbb", "subnet-ccccccccccccccc"]
manage_nat_for_existing_vpc = true
cluster_name               = "cluckn-bell-nonprod"
EOF

# Run terraform plan (requires AWS credentials)
terraform plan -var-file=test-nat.tfvars
```

**Expected Resources in Plan:**
- `aws_eip.nat[0]` - Elastic IP for NAT gateway
- `aws_nat_gateway.this[0]` - NAT gateway resource
- `data.aws_route_table.private_rt["subnet-xxx"]` - Route table lookup for each private subnet (one per private subnet)
- `aws_route.private_default_to_nat["subnet-xxx"]` - Default route for each private subnet (one per private subnet)

### Test 3: Verify NAT Gateway Disabled

Test that setting `manage_nat_for_existing_vpc = false` prevents NAT gateway creation:

```bash
cd envs/nonprod

# Update test tfvars (replace with your actual VPC and subnet IDs)
cat > test-nat-disabled.tfvars <<EOF
environment                 = "devqa"
existing_vpc_id            = "vpc-xxxxxxxxxxxxxxxxx"  # Replace with your VPC ID
public_subnet_ids          = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy", "subnet-zzzzzzzzzzzzzzzzz"]
private_subnet_ids         = ["subnet-aaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbb", "subnet-ccccccccccccccc"]
manage_nat_for_existing_vpc = false
cluster_name               = "cluckn-bell-nonprod"
EOF

terraform plan -var-file=test-nat-disabled.tfvars
```

**Expected Result:** No NAT gateway, EIP, or route resources in the plan.

### Test 4: Verify Custom Public Subnet Selection

Test that specifying `nat_public_subnet_id` uses that specific subnet:

```bash
cd envs/nonprod

cat > test-nat-custom-subnet.tfvars <<EOF
environment                 = "devqa"
existing_vpc_id            = "vpc-xxxxxxxxxxxxxxxxx"  # Replace with your VPC ID
public_subnet_ids          = ["subnet-xxxxxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyyyyy", "subnet-zzzzzzzzzzzzzzzzz"]
private_subnet_ids         = ["subnet-aaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbb", "subnet-ccccccccccccccc"]
manage_nat_for_existing_vpc = true
nat_public_subnet_id       = "subnet-yyyyyyyyyyyyyyyyy"  # Second public subnet
cluster_name               = "cluckn-bell-nonprod"
EOF

terraform plan -var-file=test-nat-custom-subnet.tfvars | grep "subnet_id"
```

**Expected Result:** NAT gateway should be created in the specified subnet (subnet-yyyyyyyyyyyyyyyyy).

### Test 5: Verify New VPC Doesn't Trigger NAT Management

Test that when creating a new VPC (not reusing), the NAT management in nat.tf is skipped:

```bash
cd envs/nonprod

cat > test-new-vpc.tfvars <<EOF
environment                 = "devqa"
existing_vpc_id            = ""
manage_nat_for_existing_vpc = true
cluster_name               = "cluckn-bell-nonprod"
EOF

terraform plan -var-file=test-new-vpc.tfvars
```

**Expected Result:** NAT gateway from `nat.tf` should NOT be created (count = 0). The VPC module will handle NAT gateway creation instead.

### Test 6: Post-Apply Verification (If Applied)

After applying the configuration, verify the NAT gateway and routes are correctly configured:

```bash
# Get NAT gateway ID from Terraform output
cd envs/nonprod
terraform output nat_gateway_id

# Verify NAT gateway state
aws ec2 describe-nat-gateways \
  --nat-gateway-ids <nat-gateway-id-from-output> \
  --profile cluckin-bell-qa \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId,VpcId]' \
  --output table

# Verify route tables for private subnets (replace with your actual private subnet IDs)
PRIVATE_SUBNETS=("subnet-aaaaaaaaaaaaaaaa" "subnet-bbbbbbbbbbbbbbb" "subnet-ccccccccccccccc")
for subnet in "${PRIVATE_SUBNETS[@]}"; do
  echo "Checking routes for $subnet"
  aws ec2 describe-route-tables \
    --filters "Name=association.subnet-id,Values=$subnet" \
    --profile cluckin-bell-qa \
    --query 'RouteTables[*].Routes[?DestinationCidrBlock==`0.0.0.0/0`]' \
    --output table
done
```

**Expected Results:**
- NAT gateway state should be "available"
- Each private subnet route table should have a 0.0.0.0/0 route pointing to the NAT gateway ID
- No blackhole routes should exist

## Acceptance Criteria Verification

### AC1: NAT Gateway Creation

✅ Running `terraform plan/apply` in `envs/nonprod` with `existing_vpc_id` set produces a NAT gateway.

**Verification:**
```bash
cd envs/nonprod
# Using your actual tfvars file (nonprod.tfvars or test-nat.tfvars)
terraform plan -var-file=nonprod.tfvars | grep "aws_nat_gateway.this"
# Or using a test configuration:
# terraform plan -var-file=test-nat.tfvars | grep "aws_nat_gateway.this"
```

### AC2: Route Table Updates

✅ Private route table default routes are updated to point to the new NAT gateway.

**Verification:**
```bash
cd envs/nonprod
# Using your actual tfvars file (nonprod.tfvars or test-nat.tfvars)
terraform plan -var-file=nonprod.tfvars | grep "aws_route.private_default_to_nat"
# Or using a test configuration:
# terraform plan -var-file=test-nat.tfvars | grep "aws_route.private_default_to_nat"
```

### AC3: eksctl Node Groups Success

✅ eksctl create nodegroup subsequently succeeds (nodes join cluster).

**Verification (after apply):**
```bash
# Create a test nodegroup with eksctl
eksctl create nodegroup \
  --cluster=cluckn-bell-nonprod \
  --name=test-ng \
  --node-type=t3.small \
  --nodes=1 \
  --nodes-min=1 \
  --nodes-max=1 \
  --subnet-ids=subnet-0d1a90b43e2855061 \
  --profile=cluckin-bell-qa

# Verify nodes joined the cluster
kubectl get nodes
```

### AC4: Disable NAT Management

✅ Setting `manage_nat_for_existing_vpc=false` results in no NAT or route changes.

**Verification:**
```bash
cd envs/nonprod
terraform plan -var="manage_nat_for_existing_vpc=false" | grep -E "(aws_nat_gateway|aws_route.private)"
```

Expected: No resources planned.

## Troubleshooting

### Issue: Terraform plan fails with "Route already exists"

**Cause:** A route already exists in the route table, possibly manually created.

**Solution:**
1. Option A: Import the existing NAT gateway and routes into Terraform state:
   ```bash
   # Import NAT gateway
   terraform import aws_nat_gateway.this[0] nat-xxxxxxxxxxxxx
   
   # Import routes (one for each private subnet)
   # Note: AWS route import format is: route-table-id_destination-cidr
   terraform import 'aws_route.private_default_to_nat["subnet-xxx"]' rtb-xxxxxxxxxxxxx_0.0.0.0/0
   terraform import 'aws_route.private_default_to_nat["subnet-yyy"]' rtb-yyyyyyyyyyyyy_0.0.0.0/0
   terraform import 'aws_route.private_default_to_nat["subnet-zzz"]' rtb-zzzzzzzzzzzzz_0.0.0.0/0
   ```

2. Option B: Set `manage_nat_for_existing_vpc = false` and manage NAT manually.

### Issue: NAT gateway in wrong subnet

**Cause:** Default behavior uses the first public subnet.

**Solution:** Specify the desired subnet in your tfvars file:
```hcl
nat_public_subnet_id = "subnet-xxxxxxxxxxxxxxxxx"  # Replace with your desired public subnet ID
```

### Issue: Nodes still can't join cluster after NAT creation

**Verification Steps:**
1. Verify NAT gateway is in "available" state
2. Check security groups allow outbound traffic
3. Verify EKS cluster endpoint is accessible from private subnet
4. Check CloudWatch logs for EKS node bootstrap errors

## Cleanup

To remove test files:
```bash
cd envs/nonprod
rm -f test-*.tfvars
```

## References

- Problem Statement: Issue describing NodeCreationFailure due to missing NAT gateway
- Implementation: `envs/nonprod/nat.tf`
- Variables: `envs/nonprod/variables.tf` (lines 199-210)
- Documentation: `envs/README.md`, `docs/CLUSTERS_WITH_EKSCTL.md`
