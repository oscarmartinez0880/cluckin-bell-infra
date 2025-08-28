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
  region = "us-east-1"
  
  default_tags {
    tags = {
      Application = "cluckn-bell"
      Environment = "nonprod"
      Owner       = "oscarmartinez0880"
      ManagedBy   = "terraform"
    }
  }
}

# S3 bucket for Terraform state - nonprod account
resource "aws_s3_bucket" "tfstate" {
  bucket = "cluckn-bell-tfstate-nonprod"

  tags = {
    Name        = "cluckn-bell-tfstate-nonprod"
    Application = "cluckn-bell"
    Environment = "nonprod"
    Owner       = "oscarmartinez0880"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}