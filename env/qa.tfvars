
# QA Environment Configuration
environment = "qa"
aws_region  = "us-east-1"

# Kubernetes version
kubernetes_version = "1.29"

# Linux node group configuration for qa
linux_node_instance_types = ["m5.large", "m5.xlarge"]
linux_node_min_size       = 1
linux_node_max_size       = 8
linux_node_desired_size   = 3

# Windows node group configuration for qa
windows_node_instance_types = ["m5.2xlarge"]
windows_node_min_size       = 1
windows_node_max_size       = 6
windows_node_desired_size   = 2

# ECR configuration for qa
ecr_retain_untagged_days = 10
ecr_repositories = [
  "api",
  "web", 
  "worker",
  "cm",
  "cd"
]
environment = "qa"
aws_region  = "us-east-1"
