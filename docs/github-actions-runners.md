# GitHub Actions Self-Hosted Windows Runners

This document explains how to use the self-hosted Windows runners for Sitecore container builds in the Cluckin Bell project.

## Overview

The CI runners infrastructure provides autoscaling Windows Server 2022 runners with Docker support for building and pushing Windows containers to Amazon ECR.

## Runner Labels

The runners are configured with these labels:
- `self-hosted`
- `windows`
- `x64`
- `windows-containers`

## Using the Runners in Workflows

### Basic Usage

Target the runners in your GitHub Actions workflows using the `runs-on` key:

```yaml
name: Sitecore Build and Push

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: [self-hosted, windows, x64, windows-containers]
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Build Sitecore CM image
        run: |
          docker build -t sitecore-cm:latest -f Dockerfile.cm .
      
      - name: Configure AWS credentials for ECR
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.ECR_PUSH_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Tag and push image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: sitecore-cm
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker tag sitecore-cm:latest $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag sitecore-cm:latest $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
```

### Smoke Test Workflow

Create a smoke test workflow to validate runner functionality:

```yaml
name: Runner Smoke Test

on:
  workflow_dispatch:
  schedule:
    - cron: '0 9 * * 1'  # Weekly on Monday

jobs:
  smoke-test:
    runs-on: [self-hosted, windows, x64, windows-containers]
    
    steps:
      - name: Check Windows version
        run: |
          Get-ComputerInfo | Select WindowsProductName, WindowsVersion
      
      - name: Check Docker version
        run: |
          docker version
      
      - name: Test Windows container
        run: |
          docker run --rm mcr.microsoft.com/windows/nanoserver:ltsc2022 cmd /c echo "Windows containers working"
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.ECR_PUSH_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Test ECR login
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Test ECR push capability
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          $testImage = "mcr.microsoft.com/windows/nanoserver:ltsc2022"
          $targetImage = "$env:ECR_REGISTRY/smoke-test:$env:GITHUB_RUN_ID"
          
          docker pull $testImage
          docker tag $testImage $targetImage
          docker push $targetImage
          
          Write-Output "Successfully pushed test image to ECR: $targetImage"
```

## Environment Variables and Secrets

### Required Repository Variables

Set these in your repository settings (Settings > Secrets and variables > Actions > Variables):

- `ECR_PUSH_ROLE_ARN`: ARN of the IAM role for ECR push operations (created in PR #8)

### Optional Repository Variables

- `ECR_REGISTRY`: Your ECR registry URL (e.g., `123456789012.dkr.ecr.us-east-1.amazonaws.com`)
- `SITECORE_LICENSE`: Base64-encoded Sitecore license file (if needed for builds)

## Workflow Examples

### Sitecore CM/CD Build and Push

```yaml
name: Sitecore Build and Push

on:
  push:
    branches: [main, develop]
    paths:
      - 'src/**'
      - 'docker/**'
      - 'Dockerfile.*'

env:
  ECR_REGISTRY: ${{ vars.ECR_REGISTRY }}
  AWS_REGION: us-east-1

jobs:
  build-cm:
    runs-on: [self-hosted, windows, x64, windows-containers]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.ECR_PUSH_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build Sitecore CM image
        run: |
          docker build `
            --build-arg SITECORE_LICENSE="${{ secrets.SITECORE_LICENSE }}" `
            -t sitecore-cm:${{ github.sha }} `
            -f docker/Dockerfile.cm `
            .
      
      - name: Push to ECR
        run: |
          $ecrRepo = "${{ env.ECR_REGISTRY }}/sitecore-cm"
          $imageTag = "${{ github.sha }}"
          
          docker tag sitecore-cm:$imageTag $ecrRepo:$imageTag
          docker tag sitecore-cm:$imageTag $ecrRepo:latest
          
          docker push $ecrRepo:$imageTag
          docker push $ecrRepo:latest

  build-cd:
    runs-on: [self-hosted, windows, x64, windows-containers]
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.ECR_PUSH_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-login@v2
      
      - name: Build Sitecore CD image
        run: |
          docker build `
            --build-arg SITECORE_LICENSE="${{ secrets.SITECORE_LICENSE }}" `
            -t sitecore-cd:${{ github.sha }} `
            -f docker/Dockerfile.cd `
            .
      
      - name: Push to ECR
        run: |
          $ecrRepo = "${{ env.ECR_REGISTRY }}/sitecore-cd"
          $imageTag = "${{ github.sha }}"
          
          docker tag sitecore-cd:$imageTag $ecrRepo:$imageTag
          docker tag sitecore-cd:$imageTag $ecrRepo:latest
          
          docker push $ecrRepo:$imageTag
          docker push $ecrRepo:latest
```

## Troubleshooting

### Runner Not Available

If no runners are available:

1. Check the Auto Scaling Group in AWS Console
2. Verify the desired capacity is > 0 or set to auto-scale
3. Check CloudWatch logs for runner registration issues

### Build Failures

Common issues and solutions:

1. **Docker not found**: Ensure the runner has finished initialization
2. **ECR login fails**: Verify the ECR push role ARN is correct and has proper permissions
3. **Out of disk space**: Consider increasing the root volume size in the Terraform configuration
4. **Windows container issues**: Check that Windows container mode is enabled

### Performance Optimization

For better performance:

1. Use larger instance types (`m5.4xlarge` or `m5.8xlarge`) for complex builds
2. Enable VPC endpoints to reduce ECR/S3 latency
3. Pre-pull common base images in the user data script
4. Use EBS-optimized instances for better I/O performance

## Security Best Practices

1. **No long-lived credentials**: Always use OIDC for AWS authentication
2. **Minimal permissions**: The runners have minimal IAM permissions; use OIDC roles for specific operations
3. **Private networks**: Runners operate in private subnets with no public IP addresses
4. **Encrypted storage**: All EBS volumes are encrypted at rest
5. **Repository allowlist**: Only specified repositories can use the runners

## Monitoring and Logging

### CloudWatch Logs

Runner logs are available in CloudWatch:
- Log Group: `/aws/ec2/ci-runners`
- Log Stream: Instance ID

### Metrics

Monitor runner usage:
- Auto Scaling Group metrics in CloudWatch
- EC2 instance metrics (CPU, memory, disk)
- GitHub Actions usage in your repository insights

### Alerts

Set up CloudWatch alarms for:
- High CPU utilization across runners
- Failed instance launches
- Low available capacity during peak usage