# Example: QA environment with custom VPC and subnet CIDRs
environment = "qa"
aws_region  = "us-east-1"

# VPC configuration - if no VPC named "qa-vpc" exists, create one with custom settings
vpc_cidr              = "10.1.0.0/16"
public_subnet_cidrs   = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnet_cidrs  = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
create_vpc_if_missing = true

# EKS configuration
kubernetes_version = "1.30"

# Node group configuration
linux_node_instance_types = ["m5.large", "m5.xlarge"]
linux_node_min_size       = 1
linux_node_max_size       = 8
linux_node_desired_size   = 3

# Platform controllers
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
enable_argocd                       = true