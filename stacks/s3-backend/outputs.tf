output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "s3_bucket_region" {
  description = "AWS region of the S3 bucket"
  value       = data.aws_region.current.name
}

output "backend_config" {
  description = "Backend configuration for use in other stacks"
  value = {
    bucket = aws_s3_bucket.terraform_state.bucket
    key    = "terraform.tfstate"
    region = data.aws_region.current.name
  }
}