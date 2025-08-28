terraform {
  backend "s3" {
    bucket = "cb-infra-state-prod-346746763840"
    key    = "dns/terraform.tfstate"
    region = "us-east-1"
  }
}