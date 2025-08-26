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
      Stack       = "gha-windows-runner"
      ManagedBy   = "terraform"
    }
  }
}

module "gha_windows_runner" {
  source                        = "../../../modules/gha-windows-runner"
  name_prefix                   = "cluckin-bell"
  vpc_id                        = var.vpc_id
  subnet_id                     = var.subnet_id
  github_owner                  = var.github_owner
  github_repo                   = var.github_repo
  github_pat_ssm_parameter_name = var.github_pat_ssm_parameter_name
  runner_labels                 = ["self-hosted", "windows", "x64", "windows-containers"]
}