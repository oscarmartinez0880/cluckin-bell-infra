# Production Environment Configuration - Cluckin' Bell
# Account: 346746763840 (cluckin-bell-prod)
# Region: us-east-1

environment = "prod"
aws_region  = "us-east-1"

# Kubernetes cluster configuration
kubernetes_version = "1.29"

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

# ECR configuration for production
ecr_retain_untagged_days = 30
ecr_repositories = [
  "cluckin-bell-app",
  "wingman-api",
  "fryer-worker",
  "sauce-gateway",
  "clucker-notify"
]

# Production-specific overrides can be added here
# All standard naming will be applied via locals/naming.tf