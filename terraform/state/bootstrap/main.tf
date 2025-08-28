terraform {
  required_version = "~> 1.13.1"
}

provider "aws" {
  alias  = "devqa"
  region = "us-east-1"
}

provider "aws" {
  alias  = "prod"
  region = "us-east-1"
}

# S3 bucket for Dev/QA state
resource "aws_s3_bucket" "state_devqa" {
  provider = aws.devqa
  bucket   = "cb-infra-state-devqa-264765154707"
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "state_devqa" {
  provider = aws.devqa
  bucket   = aws_s3_bucket.state_devqa.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_devqa" {
  provider = aws.devqa
  bucket   = aws_s3_bucket.state_devqa.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_public_access_block" "state_devqa" {
  provider                = aws.devqa
  bucket                  = aws_s3_bucket.state_devqa.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket for Prod state
resource "aws_s3_bucket" "state_prod" {
  provider = aws.prod
  bucket   = "cb-infra-state-prod-346746763840"
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "state_prod" {
  provider = aws.prod
  bucket   = aws_s3_bucket.state_prod.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_prod" {
  provider = aws.prod
  bucket   = aws_s3_bucket.state_prod.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

resource "aws_s3_bucket_public_access_block" "state_prod" {
  provider                = aws.prod
  bucket                  = aws_s3_bucket.state_prod.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "devqa_state_bucket" { value = aws_s3_bucket.state_devqa.bucket }
output "prod_state_bucket"  { value = aws_s3_bucket.state_prod.bucket }