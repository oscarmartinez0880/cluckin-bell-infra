# QA Environment Configuration - Cluckin' Bell
# Account: 264765154707 (cluckin-bell-qa)
# Region: us-east-1

environment = "qa"
aws_region  = "us-east-1"

# Kubernetes cluster configuration
kubernetes_version = "1.29"

# Linux node group configuration for QA
linux_node_instance_types = ["m5.large", "m5.xlarge"]
linux_node_min_size       = 1
linux_node_max_size       = 8
linux_node_desired_size   = 3

# Windows node group configuration for QA
windows_node_instance_types = ["m5.2xlarge"]
windows_node_min_size       = 1
windows_node_max_size       = 6
windows_node_desired_size   = 2

# ECR configuration for QA
ecr_retain_untagged_days = 10
ecr_repositories = [
  "cluckin-bell-app",
  "wingman-api", 
  "fryer-worker",
  "sauce-gateway",
  "clucker-notify"
]

# QA-specific overrides can be added here
# All standard naming will be applied via locals/naming.tf