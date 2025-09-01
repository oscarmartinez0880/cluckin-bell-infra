# Production Environment with Required Existing VPC Configuration - Cluckin' Bell  
# Account: 346746763840 (cluckin-bell-prod)
# Region: us-east-1
# Purpose: Example configuration for prod environment requiring existing VPC and SSO

environment = "prod"
aws_region  = "us-east-1"
aws_profile = "cluckin-bell-prod-admin"

# VPC configuration
create_vpc_if_missing = false
existing_vpc_name     = "prod-cluckin-bell-vpc"
vpc_cidr              = "10.1.0.0/16"  # Only used if VPC creation was enabled

# Route53 management
manage_route53 = true

# Kubernetes cluster configuration
kubernetes_version = "1.30"

# Linux node group configuration for production
linux_node_instance_types = ["m5.xlarge", "m5.2xlarge"]
linux_node_min_size       = 2
linux_node_max_size       = 15
linux_node_desired_size   = 5

# Windows node group configuration for production
windows_node_instance_types = ["m5.2xlarge"]
windows_node_min_size       = 1
windows_node_max_size       = 6
windows_node_desired_size   = 3

# Enable Kubernetes controllers
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
enable_argocd                       = true

# ECR configuration for production
ecr_retain_untagged_days = 30
ecr_repositories = [
  "cluckin-bell-app",
  "wingman-api",
  "fryer-worker",
  "sauce-gateway",
  "clucker-notify"
]

# Production-specific TLS/DNS settings
letsencrypt_email = "admin@cluckn-bell.com"
argocd_auto_sync  = false