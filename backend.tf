# Terraform backend configuration
# This is currently set to local backend for development
# For production, use S3 backend after running the s3-backend bootstrap stack

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }

  # S3 backend configuration (use after bootstrap):
  # 1. Deploy stacks/s3-backend first
  # 2. Copy backend.hcl.example to backend.hcl and update with your account ID
  # 3. Run: terraform init -backend-config=backend.hcl -migrate-state
  # 
  # backend "s3" {
  #   bucket  = "tfstate-cluckn-bell-ACCOUNT_ID"
  #   key     = "terraform.tfstate"
  #   region  = "us-east-1"
  #   encrypt = true
  # }
}