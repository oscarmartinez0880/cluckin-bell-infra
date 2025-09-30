# Dev/QA Environment Configuration - Cluckin' Bell (shared cluster in 264765154707)
environment = "devqa"
aws_region  = "us-east-1"
aws_profile = "cluckin-bell-qa"

# VPC configuration
create_vpc_if_missing = true
existing_vpc_name     = ""
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidrs   = [] # auto-calc 3 AZs
private_subnet_cidrs  = [] # auto-calc 3 AZs

# Route53 management
manage_route53 = true
# Public and Private Route53 zones for devqa
#public_zone = {
#  create = false
#  name   = ["dev.cluckn-bell.com.", "qa.cluckn-bell.com."]
#}

#private_zone = {
#  create = false
#  name   = "cluckn-bell.com."
#  vpc_id = "vpc-0749517f2c92924a5" # Set this to your VPC ID if needed, or leave empty if handled elsewhere
#}

# EKS configuration
kubernetes_version = "1.33"

# Node groups (nonprod defaults)
linux_node_instance_types = ["m5.large", "m5.xlarge"]
linux_node_min_size       = 1
linux_node_max_size       = 5
linux_node_desired_size   = 2

windows_node_instance_types = ["m5.2xlarge"]
windows_node_min_size       = 1
windows_node_max_size       = 6
windows_node_desired_size   = 2

# Controllers
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
enable_argocd                       = true

# ECR
ecr_retain_untagged_days = 10
ecr_repositories = [
  "cluckin-bell-app",
  "wingman-api",
  "fryer-worker",
  "sauce-gateway",
  "clucker-notify"
]

# SSO Admin role - grant cluster-admin to the Dev/QA SSO Admin role in shared dev/qa cluster
sso_admin_role_arn = "arn:aws:iam::264765154707:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess-Bootstrap_f590cd8336ea48d9"