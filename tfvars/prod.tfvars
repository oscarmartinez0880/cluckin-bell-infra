# Production Environment Configuration - Cluckin' Bell
# Production account (346746763840)
# Region: us-east-1

environment = "prod"
aws_region  = "us-east-1"
aws_profile = "cluckin-bell-prod"

# VPC configuration - create VPC if missing to avoid discovery failures
create_vpc_if_missing = true
existing_vpc_name     = "" # fallback to create
vpc_cidr              = "10.2.0.0/16"
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

# Grant cluster-admin to the SSO Admin role in Prod (optional but recommended)
# Provided by user
sso_admin_role_arn = "arn:aws:iam::346746763840:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess-Bootstrap_f10526eb002c08f2"