# Example: Production environment that requires existing VPC
environment = "prod"
aws_region  = "us-east-1"

# VPC configuration - require existing VPC named "prod-vpc" (fail if not found)
create_vpc_if_missing = false

# EKS configuration
kubernetes_version = "1.30"

# Node group configuration
linux_node_instance_types = ["m5.xlarge", "m5.2xlarge"]
linux_node_min_size       = 3
linux_node_max_size       = 15
linux_node_desired_size   = 5

# Platform controllers
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
enable_argocd                       = true