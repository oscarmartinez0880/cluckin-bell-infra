# CI Runners Module

This module creates autoscaling Windows Server 2022 GitHub Actions runners for Sitecore container builds on AWS.

## Features

- **Ephemeral Runners**: Scale-from-zero architecture with per-job runners
- **Windows Containers**: Windows Server 2022 Core with Docker support
- **Private Network**: Runners operate in private subnets behind NAT
- **ECR Integration**: Built-in support for pushing to Amazon ECR via OIDC
- **Auto Scaling**: Configurable min/max instances with optional webhook scaling
- **Security**: Minimal IAM permissions, encrypted storage, VPC endpoints
- **Monitoring**: Optional SSM access for patching and logging

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                          VPC                                │
│  ┌─────────────────┐                                        │
│  │  Public Subnet  │                                        │
│  │  ┌────────────┐ │   ┌─────────────────────────────────┐  │
│  │  │ NAT Gateway│ │   │        Private Subnets          │  │
│  │  └────────────┘ │   │  ┌─────────────────────────────┐│  │
│  └─────────────────┘   │  │    Auto Scaling Group       ││  │
│           │             │  │  ┌─────────────────────────┐││  │
│           │             │  │  │  Windows Runners        │││  │
│  ┌─────────────────┐   │  │  │  - GitHub Actions       │││  │
│  │ Internet Gateway│◄──┤  │  │  - Docker Windows       │││  │
│  └─────────────────┘   │  │  │  - ECR Push via OIDC    │││  │
│                         │  │  └─────────────────────────┘││  │
│                         │  └─────────────────────────────┘│  │
│                         └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Configuration

```hcl
module "ci_runners" {
  source = "./modules/ci-runners"

  name_prefix = "cluckin-bell-dev"
  
  # GitHub App configuration
  github_app_id                        = "123456"
  github_app_installation_id           = "789012"
  github_app_private_key_ssm_parameter = "/github/app/private-key"
  
  # Repository allowlist
  github_repository_allowlist = ["oscarmartinez0880/cluckin-bell-app"]
  
  # Instance configuration
  instance_type      = "m5.2xlarge"
  root_volume_size   = 150
  
  # Auto scaling
  min_size         = 0
  max_size         = 5
  desired_capacity = 0
  
  tags = {
    Environment = "dev"
    Project     = "cluckin-bell"
    ManagedBy   = "terraform"
  }
}
```

### Advanced Configuration

```hcl
module "ci_runners" {
  source = "./modules/ci-runners"

  name_prefix = "cluckin-bell-prod"
  
  # Network configuration
  vpc_cidr             = "10.1.0.0/16"
  private_subnet_count = 3
  enable_vpc_endpoints = true
  
  # GitHub App configuration
  github_app_id                        = "123456"
  github_app_installation_id           = "789012"
  github_app_private_key_ssm_parameter = "/github/app/private-key"
  
  # Repository and runner configuration
  github_repository_allowlist = [
    "oscarmartinez0880/cluckin-bell-app",
    "oscarmartinez0880/cluckin-bell-web"
  ]
  
  runner_labels = [
    "self-hosted",
    "windows",
    "x64", 
    "windows-containers",
    "sitecore"
  ]
  
  # Instance configuration
  instance_type      = "m5.4xlarge"
  root_volume_size   = 200
  root_volume_type   = "gp3"
  
  # Auto scaling
  min_size         = 0
  max_size         = 10
  desired_capacity = 1
  
  # Optional features
  enable_ssm_access = true
  enable_webhook    = true
  
  tags = {
    Environment = "prod"
    Project     = "cluckin-bell"
    ManagedBy   = "terraform"
  }
}
```

## Prerequisites

### GitHub App Setup

1. Create a GitHub App with the following permissions:
   - **Repository permissions**:
     - Actions: Read
     - Administration: Read
     - Metadata: Read
   - **Organization permissions**:
     - Self-hosted runners: Write

2. Install the GitHub App on your organization/repositories

3. Store the private key in AWS SSM Parameter Store:
   ```bash
   aws ssm put-parameter \
     --name "/github/app/private-key" \
     --value "$(cat path/to/your/github-app-private-key.pem)" \
     --type "SecureString" \
     --description "GitHub App private key for CI runners"
   ```

### ECR Push Role (OIDC)

Ensure you have an existing IAM role for ECR push operations that can be assumed via GitHub OIDC. The runners will use GitHub OIDC to assume this role for pushing images to ECR.

## Outputs

- `autoscaling_group_name`: Name of the Auto Scaling Group
- `runner_labels`: Labels assigned to the runners
- `base_ami_id`: AMI ID used for the runners  
- `webhook_endpoint_url`: Webhook URL (if enabled)

## Runner Labels

The runners are configured with the following labels by default:
- `self-hosted`
- `windows` 
- `x64`
- `windows-containers`

Use these labels in your GitHub Actions workflows:

```yaml
jobs:
  build:
    runs-on: [self-hosted, windows, x64, windows-containers]
    steps:
      - uses: actions/checkout@v4
      # Your Windows container build steps
```

## Security Considerations

- Runners operate in private subnets with no public IP addresses
- All egress traffic goes through NAT Gateway
- Minimal IAM permissions granted to runner instances
- EBS volumes are encrypted
- VPC endpoints available for ECR and S3 (optional)
- No long-lived AWS credentials; uses OIDC for ECR access

## Troubleshooting

### Runner Registration Issues

1. Check CloudWatch logs in the Auto Scaling Group instances
2. Verify GitHub App permissions and installation
3. Ensure SSM parameter contains valid private key
4. Check that repository is in the allowlist

### Docker Issues

1. Verify Windows container mode is enabled
2. Check Docker service status in runner instances
3. Test with simple Windows container: `mcr.microsoft.com/windows/nanoserver:ltsc2022`

### Network Connectivity

1. Verify NAT Gateway is running and properly configured
2. Check security group rules allow outbound HTTPS
3. Ensure VPC endpoints are configured if using private ECR access