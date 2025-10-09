# EKS Cluster Management with eksctl

This document describes the operating model for managing EKS clusters in the cluckin-bell infrastructure.

**Important**: Terraform does NOT create or manage EKS clusters or node groups. eksctl is the single source of truth for all cluster lifecycle operations.

## Operating Model

The infrastructure follows a separation of concerns:

1. **Terraform** - Manages foundational AWS resources:
   - VPCs, subnets, route tables, NAT gateways
   - Route53 hosted zones
   - ECR repositories
   - WAF rules
   - VPC endpoints
   - IAM roles (including IRSA roles, post-cluster creation)
   - **Note**: Terraform references existing eksctl-managed clusters via data sources for post-cluster configuration only

2. **eksctl** - Manages EKS cluster lifecycle (v1.34):
   - Cluster creation and upgrades
   - Kubernetes version management
   - Node group management
   - Add-on versions
   - **This is the ONLY tool for cluster lifecycle management**

3. **Argo CD / Helm** - Manages in-cluster resources:
   - Application deployments
   - Kubernetes controllers (ALB controller, external-dns, cert-manager)
   - Platform components

## Why This Model?

### Benefits

1. **Clear separation of concerns**: Infrastructure vs. cluster vs. applications
2. **Reduced risk**: Terraform changes won't accidentally modify or destroy clusters
3. **Simplified operations**: eksctl is purpose-built for EKS management
4. **Version control**: Kubernetes version pinned to 1.34 in eksctl configs
5. **Cost optimization**: Easy to use AL2023 AMI and right-size node groups
6. **Single source of truth**: eksctl is the only tool for cluster lifecycle management

### Trade-offs

- Must coordinate between tools (Terraform → eksctl → IRSA → Helm)
- OIDC issuer URL must be manually retrieved and passed to IRSA stack
- Two-step process for full cluster setup

**Note**: Terraform does not manage EKS clusters or node groups. eksctl is the single source of truth for cluster lifecycle management.

## Cluster Architecture

### Nonprod Cluster (cluckn-bell-nonprod)
- **Account**: 264765154707 (cluckin-bell-qa)
- **Region**: us-east-1
- **Version**: 1.34
- **VPC**: cb-devqa-use1 (10.60.0.0/16)
- **Node Groups**:
  - `dev`: 1-5 nodes, m5.large, AL2023, for dev workloads
  - `qa`: 1-8 nodes, m5.large, AL2023, for qa workloads

### Prod Cluster (cluckn-bell-prod)
- **Account**: 346746763840 (cluckin-bell-prod)
- **Region**: us-east-1
- **Version**: 1.34
- **VPC**: cb-prod-use1 (10.70.0.0/16)
- **Node Groups**:
  - `prod`: 2-15 nodes, m5.xlarge, AL2023, for production workloads

## Step-by-Step Setup

### Prerequisites

Install required tools:
```bash
# eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# AWS CLI v2 (if not already installed)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Terraform (if not already installed)
wget https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
unzip terraform_1.5.7_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### Step 1: Deploy Foundational Infrastructure with Terraform

Deploy VPCs, subnets, and other foundational resources:

```bash
# Deploy nonprod VPC and networking
cd envs/nonprod
terraform init
terraform plan
terraform apply

# Note the VPC ID and subnet IDs from outputs
terraform output vpc_id
terraform output private_subnet_ids
terraform output public_subnet_ids
```

**Note**: During initial setup (before the cluster exists), Terraform will show warnings about the cluster data source not being found. This is expected and safe to ignore. The cluster-related resources (IRSA roles, Kubernetes/Helm providers) use `try()` functions to gracefully handle missing clusters. After you create the cluster with eksctl in Step 3, run `terraform apply` again to provision the cluster-dependent resources.

**Important: NAT Gateway for Existing VPCs (Nonprod)**

When reusing an existing VPC (as configured in `envs/nonprod`), Terraform automatically provisions a NAT gateway to ensure private subnets have egress connectivity. This is critical for EKS nodes to successfully join the cluster and pull container images.

By default, Terraform will:
- Create an Elastic IP and NAT gateway in the first public subnet
- Update all private subnet route tables with a default route (0.0.0.0/0) to the NAT gateway
- Replace any existing blackhole routes that may exist

This behavior is controlled by the `manage_nat_for_existing_vpc` variable (default: `true`). To disable automatic NAT management:

```hcl
# In envs/nonprod/nonprod.tfvars or via CLI
manage_nat_for_existing_vpc = false
```

To use a specific public subnet for the NAT gateway:

```hcl
nat_public_subnet_id = "subnet-09a601564fef30599"
```

If you skip this step, eksctl nodegroups may fail with `NodeCreationFailure` errors due to nodes being unable to reach the EKS API endpoint or pull images.

### Step 2: Update eksctl Configuration

Edit the eksctl configuration files and replace placeholders with actual IDs:

```bash
# Update eksctl/devqa-cluster.yaml
# Replace:
#   vpc-REPLACE_WITH_VPC_ID with actual VPC ID
#   subnet-REPLACE_WITH_SUBNET_* with actual subnet IDs

# Update eksctl/prod-cluster.yaml
# Same as above for prod VPC
```

### Step 3: Create EKS Cluster with eksctl

Use the provided script:

```bash
# Create nonprod cluster
./scripts/eks/create-clusters.sh nonprod

# Or create prod cluster
./scripts/eks/create-clusters.sh prod

# Or create both
./scripts/eks/create-clusters.sh all
```

Manual approach (if needed):
```bash
# Nonprod
export AWS_PROFILE=cluckin-bell-qa
eksctl create cluster --config-file=eksctl/devqa-cluster.yaml

# Prod
export AWS_PROFILE=cluckin-bell-prod
eksctl create cluster --config-file=eksctl/prod-cluster.yaml
```

This will take 15-20 minutes per cluster.

### Step 4: Get OIDC Issuer URL

After cluster creation, get the OIDC issuer URL:

```bash
# Nonprod
aws eks describe-cluster \
  --name cluckn-bell-nonprod \
  --region us-east-1 \
  --profile cluckin-bell-qa \
  --query 'cluster.identity.oidc.issuer' \
  --output text

# Prod
aws eks describe-cluster \
  --name cluckn-bell-prod \
  --region us-east-1 \
  --profile cluckin-bell-prod \
  --query 'cluster.identity.oidc.issuer' \
  --output text
```

### Step 5: Bootstrap IRSA Roles

Create IAM roles for Kubernetes service accounts:

```bash
cd stacks/irsa-bootstrap

# Create nonprod.tfvars
cat > nonprod.tfvars <<EOF
cluster_name          = "cluckn-bell-nonprod"
region                = "us-east-1"
aws_profile           = "cluckin-bell-qa"
oidc_issuer_url       = "https://oidc.eks.us-east-1.amazonaws.com/id/XXXXX"
environment           = "nonprod"
controllers_namespace = "kube-system"
EOF

# Apply for nonprod
terraform init
terraform apply -var-file=nonprod.tfvars

# Get role ARNs for Helm/Argo CD
terraform output helm_values
```

Repeat for prod with `prod.tfvars`.

### Step 6: Deploy Controllers

Deploy Kubernetes controllers via Helm or Argo CD using the IAM role ARNs from the previous step.

Example Helm deployment:

```bash
# Update kubeconfig
aws eks update-kubeconfig --name cluckn-bell-nonprod --region us-east-1 --profile cluckin-bell-qa

# Add Helm repos
helm repo add eks https://aws.github.io/eks-charts
helm repo add jetstack https://charts.jetstack.io
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Get role ARNs from Terraform output
cd stacks/irsa-bootstrap
export ALB_ROLE_ARN=$(terraform output -raw aws_load_balancer_controller_role_arn)
export EXTDNS_ROLE_ARN=$(terraform output -raw external_dns_role_arn)
export CERTMGR_ROLE_ARN=$(terraform output -raw cert_manager_role_arn)

# Deploy AWS Load Balancer Controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=cluckn-bell-nonprod \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN

# Deploy external-dns
helm install external-dns bitnami/external-dns \
  -n kube-system \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EXTDNS_ROLE_ARN \
  --set provider=aws \
  --set aws.region=us-east-1

# Deploy cert-manager
helm install cert-manager jetstack/cert-manager \
  -n kube-system \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$CERTMGR_ROLE_ARN \
  --set installCRDs=true
```

## Ongoing Management

### Upgrading Kubernetes Version

1. Update version in `eksctl/*.yaml` files
2. Run upgrade:
   ```bash
   eksctl upgrade cluster --config-file=eksctl/devqa-cluster.yaml --profile=cluckin-bell-qa --approve
   ```

### Scaling Node Groups

Edit `eksctl/*.yaml` and run:
```bash
eksctl scale nodegroup --cluster=cluckn-bell-nonprod --name=dev --nodes=3 --profile=cluckin-bell-qa
```

Or update the config and apply:
```bash
eksctl update nodegroup --config-file=eksctl/devqa-cluster.yaml --profile=cluckin-bell-qa
```

### Updating Add-ons

```bash
eksctl update addon --cluster=cluckn-bell-nonprod --name=vpc-cni --version=latest --profile=cluckin-bell-qa
```

## Cost Optimization Tips

### Node Group Sizing
- Start with minimal desired sizes (1-2 nodes)
- Use cluster autoscaler to scale based on demand
- AL2023 AMI is free (no license cost)

### NAT Gateway vs. VPC Endpoints
- NAT Gateway: ~$33/month + data transfer
- VPC Endpoints: ~$7/month per endpoint
- For dev/qa: Consider single NAT gateway
- For prod: Use one NAT gateway per AZ for HA

### Log Retention
- Nonprod: 7 days (configured in eksctl YAML)
- Prod: 90 days
- Adjust based on compliance requirements

### Instance Types
- Dev: m5.large (2 vCPU, 8 GB RAM)
- QA: m5.large
- Prod: m5.xlarge (4 vCPU, 16 GB RAM)
- Adjust based on actual workload requirements

## Troubleshooting

### Cluster Creation Fails

Check IAM permissions:
```bash
aws sts get-caller-identity --profile cluckin-bell-qa
```

Ensure VPC and subnets exist:
```bash
cd terraform/clusters/devqa
terraform output
```

### NodeCreationFailure - Nodes Can't Join Cluster

If eksctl reports `NodeCreationFailure` or nodes fail to join the cluster, check NAT gateway and routing:

```bash
# Verify NAT gateway exists and is available
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=vpc-0749517f2c92924a5" \
  --profile cluckin-bell-qa \
  --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' \
  --output table

# Check private subnet route tables have NAT gateway routes
aws ec2 describe-route-tables \
  --filter "Name=association.subnet-id,Values=subnet-0d1a90b43e2855061" \
  --profile cluckin-bell-qa \
  --query 'RouteTables[*].Routes' \
  --output table
```

Expected output: Route table should have a 0.0.0.0/0 route pointing to a NAT gateway (not blackhole).

If NAT gateway is missing:
```bash
cd envs/nonprod
terraform apply  # Will create NAT gateway and update routes
```

### OIDC Provider Issues

Verify OIDC issuer URL is correct:
```bash
aws eks describe-cluster --name cluckn-bell-nonprod --query 'cluster.identity.oidc.issuer' --output text
```

Check IAM OIDC provider exists:
```bash
aws iam list-open-id-connect-providers
```

### IRSA Role Not Working

Verify service account annotation:
```bash
kubectl get sa -n kube-system aws-load-balancer-controller -o yaml
```

Check pod logs:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

## References

- [eksctl Documentation](https://eksctl.io/)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [ExternalDNS](https://github.com/kubernetes-sigs/external-dns)
- [cert-manager](https://cert-manager.io/)
- [PR #73: Kubernetes 1.33 Support](https://github.com/oscarmartinez0880/cluckin-bell-infra/pull/73)

## Contact

For questions or issues, please open an issue in the repository or contact the platform team.
