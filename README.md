# Cluckin Bell Infrastructure

This repository contains production-grade Infrastructure as Code (IaC) using Terraform for the Cluckin Bell application platform on AWS. The infrastructure provides a complete, secure, and scalable foundation for Kubernetes workloads using Amazon EKS.

## 🏗️ Architecture Overview

The infrastructure includes:

- **Networking**: VPC with public/private subnets across multiple AZs
- **Container Platform**: Amazon EKS with production-ready configuration
- **Container Registry**: Amazon ECR for container image storage
- **Databases**: Amazon RDS (PostgreSQL) and ElastiCache (Redis)
- **Storage**: Amazon EFS for shared persistent storage
- **Security**: IAM roles with IRSA (IAM Roles for Service Accounts)
- **Monitoring**: CloudWatch integration with alerting
- **CI/CD**: GitHub Actions OIDC integration

## 📁 Repository Structure

```
├── modules/                    # Reusable Terraform modules
│   ├── vpc/                   # VPC and networking
│   ├── eks/                   # Amazon EKS cluster
│   ├── ecr/                   # Container registry
│   ├── rds/                   # PostgreSQL database
│   ├── elasticache/           # Redis cache
│   ├── efs/                   # Shared file storage
│   ├── iam/                   # IAM roles and policies
│   └── monitoring/            # CloudWatch monitoring
├── env/                       # Environment-specific configurations
│   ├── dev.tfvars            # Development environment
│   ├── qa.tfvars             # QA environment
│   └── prod.tfvars           # Production environment
├── main.tf                    # Root Terraform configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
└── .github/workflows/         # CI/CD workflows
```

## 🚀 Quick Start

### Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **kubectl** for Kubernetes cluster access (optional)

### 1. Configure Backend (First Time Setup)

Create an S3 bucket and DynamoDB table for Terraform state:

```bash
# Create backend configuration file
cat > backend.hcl << EOF
bucket         = "your-terraform-state-bucket"
key            = "terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-state-lock"
encrypt        = true
EOF

# Initialize with backend
terraform init -backend-config=backend.hcl
```

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment for development environment
terraform plan -var-file=env/dev.tfvars

# Apply changes
terraform apply -var-file=env/dev.tfvars
```

### 3. Configure Kubernetes Access

After EKS deployment, configure kubectl:

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name cluckin-bell-dev-eks

# Verify access
kubectl get nodes
```

## 🌍 Environment Configuration

### Development (`env/dev.tfvars`)
- **Purpose**: Development and testing
- **Cost Optimization**: SPOT instances, smaller node sizes
- **Security**: Public endpoint access allowed
- **Backup**: Reduced retention periods

### QA (`env/qa.tfvars`)
- **Purpose**: Quality assurance and staging
- **Configuration**: Production-like setup with moderate resources
- **Security**: Enhanced security settings
- **Monitoring**: Full monitoring enabled

### Production (`env/prod.tfvars`)
- **Purpose**: Production workloads
- **High Availability**: Multi-AZ deployment
- **Security**: Private endpoint access only
- **Performance**: Larger instances, optimized configuration
- **Backup**: Extended retention periods

## 🔧 Customization

### Adding New Environments

1. Create a new tfvars file in `env/`:
```bash
cp env/dev.tfvars env/staging.tfvars
# Edit staging.tfvars with environment-specific values
```

2. Add GitHub Actions workflow:
```yaml
# .github/workflows/terraform-staging.yml
name: Terraform Staging
on:
  push:
    branches: [ "staging" ]
# ... rest of workflow configuration
```

### Module Configuration

Each module can be customized through variables. Key configuration options:

- **EKS**: Node group sizes, instance types, add-ons
- **RDS**: Instance class, storage, backup settings
- **VPC**: CIDR blocks, subnet configuration
- **Monitoring**: Alert thresholds, notification endpoints

## 🔐 Security Features

### IAM Roles for Service Accounts (IRSA)
- **EBS CSI Driver**: Persistent volume management
- **VPC CNI**: Network interface management
- **AWS Load Balancer Controller**: Application load balancing
- **Cluster Autoscaler**: Automatic node scaling

### Network Security
- **Private Subnets**: Database and cache instances isolated
- **Security Groups**: Least privilege access
- **VPC Endpoints**: Secure AWS service access
- **Network ACLs**: Additional network-level protection

### GitHub Actions Integration
- **OIDC Provider**: Secure authentication without long-lived credentials
- **Role-based Access**: Least privilege CI/CD permissions
- **Environment Separation**: Isolated access per environment

## 📊 Monitoring and Alerting

### Built-in Monitoring
- **CloudWatch Logs**: Centralized log aggregation
- **CloudWatch Metrics**: Infrastructure and application metrics
- **SNS Notifications**: Email/SMS alerts
- **Application Insights**: Automated application monitoring

### Custom Alerts
Configure email notifications by setting:
```hcl
monitoring_email_endpoints = ["alerts@yourcompany.com"]
```

## 🔄 CI/CD Workflows

### GitHub Actions Workflows
- **terraform-pr.yml**: Plan on pull requests
- **terraform-dev.yml**: Deploy to development
- **terraform-qa.yml**: Deploy to QA
- **terraform-prod.yml**: Deploy to production
- **iac-security.yml**: Security scanning with tfsec

### Workflow Triggers
- **Pull Requests**: Automatic planning and validation
- **Branch Pushes**: Automatic deployment to corresponding environments
- **Manual Triggers**: On-demand deployment with apply flag

## 🔧 Maintenance

### Regular Tasks
1. **Update Kubernetes Version**: Modify `kubernetes_version` variable
2. **Rotate Secrets**: Use AWS Secrets Manager integration
3. **Review Security**: Regular tfsec and checkov scans
4. **Monitor Costs**: Use AWS Cost Explorer and set budgets

### Scaling Operations
- **Horizontal**: Modify `eks_max_size` for more nodes
- **Vertical**: Change `eks_instance_types` for larger nodes
- **Database**: Increase `rds_instance_class` for more performance

## 🆘 Troubleshooting

### Common Issues

**EKS Node Group Creation Fails**
```bash
# Check IAM roles and policies
aws iam get-role --role-name cluckin-bell-dev-node-group-role
```

**RDS Connection Issues**
```bash
# Verify security group rules
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

**Terraform State Lock**
```bash
# Force unlock if needed (use carefully)
terraform force-unlock LOCK_ID
```

### Debugging Commands
```bash
# Terraform debugging
export TF_LOG=DEBUG
terraform plan -var-file=env/dev.tfvars

# AWS CLI debugging
aws eks describe-cluster --name cluckin-bell-dev-eks
aws rds describe-db-instances --db-instance-identifier cluckin-bell-dev-db
```

## 📞 Support

For infrastructure issues:
1. Check CloudWatch logs and metrics
2. Review Terraform state and plan output
3. Consult AWS documentation for service-specific issues
4. Use GitHub Issues for infrastructure code problems

## 📄 License

This infrastructure code is proprietary to Cluckin Bell and intended for internal use only.

---

**Note**: This README assumes you have appropriate AWS permissions and have configured your AWS CLI with valid credentials. Always review and test changes in development before applying to production environments.