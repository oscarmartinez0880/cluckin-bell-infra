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
kubernetes_version = "1.34"

# Controllers
enable_aws_load_balancer_controller = true
enable_cert_manager                 = true
enable_external_dns                 = true
enable_argocd                       = true

# Name servers from nonprod dev zone (get from: terraform output dev_zone_name_servers)
# These must be obtained from the nonprod environment and updated here
dev_zone_name_servers = [
  "ns-1234.awsdns-12.com.",
  "ns-5678.awsdns-56.co.uk.",
  "ns-9012.awsdns-90.net.",
  "ns-3456.awsdns-34.org."
]

# Name servers from nonprod qa zone (get from: terraform output qa_zone_name_servers)  
# These must be obtained from the nonprod environment and updated here
qa_zone_name_servers = [
  "ns-1111.awsdns-11.com.",
  "ns-2222.awsdns-22.co.uk.",
  "ns-3333.awsdns-33.net.",
  "ns-4444.awsdns-44.org."
]

# SSO Admin role - grant cluster-admin to the Prod SSO Admin role in prod cluster
sso_admin_role_arn = "arn:aws:iam::346746763840:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AdminAccess-Bootstrap_f10526eb002c08f2"

existing_vpc_id = "vpc-0c33a4bf182550b55"
public_subnet_ids = [
  "subnet-058d9ae9ff9399cb6",
  "subnet-0fd7aac0afed270b0",
  "subnet-06b04efdad358c264"
]
private_subnet_ids = [
  "subnet-09722cf26237fc552",
  "subnet-0fb6f763ab136eb0b",
  "subnet-0bbb317a18c2a6386"
]
cluster_name               = "cluckn-bell-prod"
cluster_log_retention_days = 90
public_access_cidrs        = ["0.0.0.0/0"] # TODO: tighten

prod_node_group_instance_types = ["t3.small"]
prod_node_group_sizes          = { min = 2, desired = 2, max = 4 }