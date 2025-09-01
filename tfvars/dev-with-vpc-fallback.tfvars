# Example: Development environment with custom VPC CIDR
environment = "dev"
aws_region  = "us-east-1"

# VPC configuration - if no VPC named "dev-vpc" exists, create one with these settings
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidrs   = [] # Will auto-calculate: ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs  = [] # Will auto-calculate: ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
create_vpc_if_missing = true

# EKS configuration
kubernetes_version = "1.30"

# Node group configuration
linux_node_instance_types = ["m5.large", "m5.xlarge"]
linux_node_min_size       = 1
linux_node_max_size       = 5
linux_node_desired_size   = 2

# Platform controllers
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
enable_argocd                       = true