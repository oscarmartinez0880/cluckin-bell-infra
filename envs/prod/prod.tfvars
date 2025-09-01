# Production Environment Configuration - Cluckin' Bell (346746763840)
environment = "prod"
aws_region  = "us-east-1"
aws_profile = "cluckin-bell-prod"

# VPC configuration
create_vpc_if_missing = true
existing_vpc_name     = ""
vpc_cidr              = "10.2.0.0/16"
public_subnet_cidrs   = [] # auto-calc 3 AZs
private_subnet_cidrs  = [] # auto-calc 3 AZs

# Route53 management
manage_route53 = true

# EKS configuration
kubernetes_version = "1.30"

# Controllers
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
enable_argocd                       = true

# Optional: grant cluster-admin to the Prod SSO Admin role
sso_admin_role_arn = "arn:aws:iam::346746763840:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess-Bootstrap_f10526eb002c08f2"