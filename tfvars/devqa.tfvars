# DevQA Environment Configuration - Cluckin' Bell
# Shared Dev/QA cluster for cluckin-bell-qa account (264765154707)
# Region: us-east-1

environment = "devqa"
aws_region  = "us-east-1"
aws_profile = "cluckin-bell-qa"

# VPC configuration - create VPC if missing with default naming
create_vpc_if_missing = true
existing_vpc_name     = ""
vpc_cidr              = "10.0.0.0/16"
public_subnet_cidrs   = [] # auto-calc 3 AZs
private_subnet_cidrs  = [] # auto-calc 3 AZs

# Route53 management
manage_route53 = true

# EKS configuration
kubernetes_version = "1.30"

# Platform controllers
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
enable_argocd                       = true

# Grant cluster-admin to the SSO Admin role in Dev/QA (optional but recommended)
# Provided by user
sso_admin_role_arn = "arn:aws:iam::264765154707:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess-Bootstrap_f590cd8336ea48d9"