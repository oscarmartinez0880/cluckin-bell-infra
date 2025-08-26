
# Development Environment Configuration
environment = "dev"
aws_region  = "us-east-1"

# Kubernetes version
kubernetes_version = "1.29"

# Linux node group configuration for dev
linux_node_instance_types = ["m5.large", "m5.xlarge"]
linux_node_min_size       = 1
linux_node_max_size       = 5
linux_node_desired_size   = 2

# Windows node group configuration for dev
windows_node_instance_types = ["m5.2xlarge"]
windows_node_min_size       = 1
windows_node_max_size       = 6
windows_node_desired_size   = 2

# ECR configuration for dev
ecr_retain_untagged_days = 10
ecr_repositories = [
  "api",
  "web", 
  "worker",
  "cm",
  "cd"
]

environment = "dev"
aws_region  = "us-east-1"
