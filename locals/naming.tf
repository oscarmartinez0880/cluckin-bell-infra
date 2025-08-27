# Cluckin' Bell Infrastructure Naming Conventions
# This file provides standardized naming locals for consistent resource naming
# across all environments. These can be adopted progressively by modules and resources.

locals {
  # Core project information
  project = "cluckin-bell"
  region  = "us-east-1"

  # Account information
  accounts = {
    dev  = "264765154707" # cluckin-bell-qa (shared for dev/qa)
    qa   = "264765154707" # cluckin-bell-qa
    prod = "346746763840" # cluckin-bell-prod
  }

  account_aliases = {
    dev  = "cluckin-bell-qa"
    qa   = "cluckin-bell-qa"
    prod = "cluckin-bell-prod"
  }

  # Name prefix for resources
  name_prefix = "cluckin-bell"

  # EKS cluster naming
  eks_cluster_name = "cluckin-bell-eks-${var.environment}-${local.region}"

  # Kubernetes namespaces
  namespaces = [
    "cluckin-bell-dev",
    "cluckin-bell-qa",
    "cluckin-bell-prod"
  ]

  # IAM role name prefixes
  iam_role_prefixes = {
    ecr_pull = "cb-ecr-pull-role-${var.environment}"
    app_web  = "cb-app-web-sa-role-${var.environment}"
    api      = "cb-api-sa-role-${var.environment}"
  }

  # ECR repository names (fried chicken themed)
  ecr_repositories = [
    "cluckin-bell-app",
    "wingman-api",
    "fryer-worker",
    "sauce-gateway",
    "clucker-notify"
  ]

  # S3 bucket naming
  s3_buckets = {
    logs      = "cluckin-bell-logs-${var.environment}-${local.region}"
    artifacts = "cluckin-bell-artifacts-${var.environment}-${local.region}"
    static    = "cluckin-bell-static-${var.environment}-${local.region}"
  }

  # KMS key aliases
  kms_aliases = {
    ecr     = "alias/cb-ecr"
    secrets = "alias/cb-secrets"
    logs    = "alias/cb-logs"
  }

  # CloudWatch log group patterns
  log_groups = {
    drumstick_web = "/cluckin-bell/drumstick-web/${var.environment}"
    wingman_api   = "/cluckin-bell/wingman-api/${var.environment}"
    fryer_worker  = "/cluckin-bell/fryer-worker/${var.environment}"
  }

  # Domain names
  domains = {
    frontend = {
      dev  = "dev.cluckin-bell.com"
      qa   = "qa.cluckin-bell.com"
      prod = "cluckin-bell.com"
    }
    api = {
      dev  = "api.dev.cluckin-bell.com"
      qa   = "api.qa.cluckin-bell.com"
      prod = "api.cluckin-bell.com"
    }
  }

  # Standard tags to be applied to all resources
  common_tags = {
    Project   = local.project
    Env       = var.environment
    ManagedBy = "terraform"
    Region    = local.region
  }

  # Environment-specific tags
  tags = merge(local.common_tags, {
    Environment = var.environment
  })
}