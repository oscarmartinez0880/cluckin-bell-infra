terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "cluckin-bell"
      Stack       = "s3-backend"
      ManagedBy   = "terraform"
    }
  }
}

# Get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Create S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "tfstate-cluckn-bell-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "tfstate-cluckn-bell-${data.aws_caller_identity.current.account_id}"
    Description = "Terraform state bucket for Cluckin Bell infrastructure"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "terraform_state_lifecycle"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Keep current versions
    noncurrent_version_expiration {
      noncurrent_days = var.state_retention_days
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Optional: S3 bucket notification for logging (disabled by default)
resource "aws_s3_bucket_notification" "terraform_state" {
  count  = var.enable_access_logging ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  # CloudWatch logs are not configured in this simple setup
  # This can be extended later if needed
}