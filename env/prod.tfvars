
# Production Environment Configuration
environment = "prod"
aws_region  = "us-east-1"

# Kubernetes version
kubernetes_version = "1.29"

# Linux node group configuration for prod
linux_node_instance_types = ["m5.xlarge", "m5.2xlarge"]
linux_node_min_size       = 2
linux_node_max_size       = 15
linux_node_desired_size   = 5

# Windows node group configuration for prod
windows_node_instance_types = ["m5.2xlarge"]
windows_node_min_size       = 1
windows_node_max_size       = 6
windows_node_desired_size   = 3

# ECR configuration for prod
ecr_retain_untagged_days = 30
ecr_repositories = [
  "api",
  "web", 
  "worker",
  "cm",
  "cd"
]

# DNS/TLS Controllers  
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
letsencrypt_email                   = "admin@cluckin-bell.com"
