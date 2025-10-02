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

# EKS configuration
kubernetes_version = "1.33"

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

# Existing VPC/Subnets reuse
existing_vpc_id = "vpc-0749517f2c92924a5"
public_subnet_ids = [
  "subnet-09a601564fef30599",
  "subnet-0e428ee488b3accac",
  "subnet-00205cdb6865588ac"
]
private_subnet_ids = [
  "subnet-0d1a90b43e2855061",
  "subnet-0e408dd3b79d3568b",
  "subnet-00d5249fbe0695848"
]
cluster_name               = "cluckn-bell-nonprod"
cluster_log_retention_days = 30
public_access_cidrs        = ["0.0.0.0/0"] # TODO: tighten

# Node group overrides (optional)
dev_node_group_instance_types = ["t3.small"]
qa_node_group_instance_types  = ["t3.small"]

dev_node_group_sizes = { min = 1, desired = 1, max = 2 }
qa_node_group_sizes  = { min = 1, desired = 1, max = 2 }