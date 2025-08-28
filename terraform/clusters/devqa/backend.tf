terraform {
  backend "s3" {
    bucket = "cb-infra-state-devqa-264765154707"
    key    = "clusters/devqa/terraform.tfstate"
    region = "us-east-1"
  }
}