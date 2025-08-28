# S3 Backend Bootstrap Stack

This stack creates the S3 bucket required for Terraform remote state storage. This should be deployed first before configuring the backend for other stacks.

## Usage

1. **Deploy the bootstrap stack using local state:**
   ```bash
   cd stacks/s3-backend
   terraform init
   terraform plan -var-file="../../env/dev.tfvars"
   terraform apply -var-file="../../env/dev.tfvars"
   ```

2. **Configure backend for main stacks:**
   After the S3 bucket is created, use the output values to configure the backend for other stacks:
   ```bash
   # Example backend.hcl
   bucket = "tfstate-cluckn-bell-123456789012"
   key    = "terraform.tfstate"
   region = "us-east-1"
   ```

3. **Migrate state to S3:**
   ```bash
   cd /path/to/main/stack
   terraform init -backend-config=backend.hcl -migrate-state
   ```

## Features

- **S3 Bucket**: Globally unique bucket name using account ID
- **Versioning**: Enabled to track state file changes
- **Encryption**: Server-side encryption with AES256
- **Public Access**: Completely blocked for security
- **Lifecycle**: Retains non-current versions for specified days, cleans up incomplete uploads
- **Access Logging**: Optional (disabled by default)

## Variables

- `environment`: Environment name (dev, qa, prod)
- `aws_region`: AWS region (default: us-east-1)
- `state_retention_days`: Days to retain non-current state versions (default: 30)
- `enable_access_logging`: Enable S3 access logging (default: false)

## Outputs

- `s3_bucket_name`: Name of the created S3 bucket
- `s3_bucket_arn`: ARN of the S3 bucket
- `s3_bucket_region`: AWS region of the bucket
- `backend_config`: Complete backend configuration object