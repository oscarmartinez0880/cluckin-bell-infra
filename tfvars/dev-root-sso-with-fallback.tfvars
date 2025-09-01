# Development Environment with VPC Fallback Configuration - Cluckin' Bell
# Account: 264765154707 (cluckin-bell-qa)
# Region: us-east-1
# Purpose: Example configuration for dev environment with VPC creation fallback and SSO

environment = "dev"
aws_region  = "us-east-1"
aws_profile = "cluckin-bell-qa-admin"

# VPC configuration
create_vpc_if_missing = true
existing_vpc_name     = "" # Will default to "dev-cluckin-bell-vpc"
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidrs   = [] # Will auto-calculate to 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
private_subnet_cidrs  = [] # Will auto-calculate to 10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24

# Route53 management
manage_route53 = true

# Kubernetes cluster configuration
kubernetes_version = "1.30"

# Linux node group configuration for development
linux_node_instance_types = ["m5.large", "m5.xlarge"]
linux_node_min_size       = 1
linux_node_max_size       = 5
linux_node_desired_size   = 2

# Windows node group configuration for development
windows_node_instance_types = ["m5.2xlarge"]
windows_node_min_size       = 1
windows_node_max_size       = 6
windows_node_desired_size   = 2

# Enable Kubernetes controllers
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
enable_argocd                       = true

# ECR configuration for development
ecr_retain_untagged_days = 10
ecr_repositories = [
  "cluckin-bell-app",
  "wingman-api",
  "fryer-worker",
  "sauce-gateway",
  "clucker-notify"
]

# Development-specific TLS/DNS settings
letsencrypt_email = "admin@cluckn-bell.com"
argocd_auto_sync  = true