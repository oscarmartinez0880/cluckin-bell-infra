# Additional variables used by envs/prod when loading prod.tfvars via -var-file
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile (informational)"
  type        = string
  default     = ""
}

variable "create_vpc_if_missing" {
  type    = bool
  default = true
}

variable "existing_vpc_name" {
  type    = string
  default = ""
}

variable "vpc_cidr" {
  type    = string
  default = "10.2.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = []
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = []
}

variable "manage_route53" {
  type    = bool
  default = true
}

variable "kubernetes_version" {
  type    = string
  default = "1.34"
  validation {
    condition     = can(regex("^1\\.(3[4-9]|[4-9][0-9])(\\..*)?$", var.kubernetes_version))
    error_message = "Kubernetes version must be 1.34 or higher."
  }
}

variable "enable_aws_load_balancer_controller" {
  type    = bool
  default = true
}

variable "enable_cert_manager" {
  type    = bool
  default = true
}

variable "enable_external_dns" {
  type    = bool
  default = true
}

variable "enable_argocd" {
  type    = bool
  default = true
}

# Node/ECR knobs in prod if you choose to use them later
variable "linux_node_instance_types" {
  type    = list(string)
  default = ["m5.large", "m5.xlarge"]
}

variable "linux_node_min_size" {
  type    = number
  default = 1
}

variable "linux_node_max_size" {
  type    = number
  default = 5
}

variable "linux_node_desired_size" {
  type    = number
  default = 2
}

variable "windows_node_instance_types" {
  type    = list(string)
  default = ["m5.2xlarge"]
}

variable "windows_node_min_size" {
  type    = number
  default = 1
}

variable "windows_node_max_size" {
  type    = number
  default = 6
}

variable "windows_node_desired_size" {
  type    = number
  default = 2
}

variable "ecr_retain_untagged_days" {
  type    = number
  default = 10
}

variable "ecr_repositories" {
  type = list(string)
  default = [
    "cluckin-bell-app",
    "wingman-api",
    "fryer-worker",
    "sauce-gateway",
    "clucker-notify"
  ]
}

variable "dev_zone_name_servers" {
  description = "Name servers for dev.cluckn-bell.com zone (from nonprod account)"
  type        = list(string)
}

variable "qa_zone_name_servers" {
  description = "Name servers for qa.cluckn-bell.com zone (from nonprod account)"
  type        = list(string)
}

# Route53 zone configuration variables for production
variable "create_public_zone" {
  description = "Whether to create the public Route53 zone for cluckn-bell.com"
  type        = bool
  default     = false
}

variable "create_internal_zone" {
  description = "Whether to create the internal private Route53 zone for internal.cluckn-bell.com"
  type        = bool
  default     = false
}

variable "internal_zone_name" {
  description = "Name for the internal private Route53 zone"
  type        = string
  default     = "internal.cluckn-bell.com"
}

variable "public_zone_name" {
  description = "Name for the public Route53 zone"
  type        = string
  default     = "cluckn-bell.com"
}

# EKS Cluster Configuration - Existing VPC/Subnet Reuse
variable "existing_vpc_id" {
  description = "ID of existing VPC to reuse for EKS cluster"
  type        = string
  default     = ""
}

variable "public_subnet_ids" {
  description = "List of existing public subnet IDs to reuse"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of existing private subnet IDs to reuse"
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "Override for EKS cluster name"
  type        = string
  default     = ""
}

variable "cluster_log_retention_days" {
  description = "CloudWatch log group retention in days for EKS cluster"
  type        = number
  default     = 90
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks for public access to the EKS cluster endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Node Group Configuration - Production Environment
variable "prod_node_group_instance_types" {
  type        = list(string)
  default     = ["t3.small"] # was t3.medium
  description = "Instance types for prod node group (lowest viable for HA)"
}

variable "prod_node_group_sizes" {
  type = object({ min = number, desired = number, max = number })
  # Keep HA with min=2 desired=2; modest max
  default = { min = 2, desired = 2, max = 4 }
}

# Feature flags for cost-safe infrastructure management
# These flags gate expensive resources to prevent accidental provisioning
variable "enable_dns" {
  description = "Enable DNS zones and certificates (Route53 costs acceptable per user)"
  type        = bool
  default     = true
}

variable "enable_ecr" {
  description = "Enable ECR repositories (costs incurred when images are stored)"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring, Container Insights, and log groups (requires enable_irsa if agents are used)"
  type        = bool
  default     = false
}

variable "enable_irsa" {
  description = "Enable all IRSA roles (requires EKS cluster with OIDC provider)"
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_irsa || var.enable_dns
    error_message = "enable_dns must be true when enable_irsa is true. IRSA modules (external-dns, cert-manager) require DNS zone IDs."
  }
}

variable "enable_cognito" {
  description = "Enable Cognito user pools (incurs costs)"
  type        = bool
  default     = false
}

variable "enable_github_oidc" {
  description = "Enable GitHub OIDC role for ECR push (requires enable_ecr=true)"
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_github_oidc || var.enable_ecr
    error_message = "enable_ecr must be true when enable_github_oidc is true. GitHub OIDC role requires ECR repository ARNs."
  }
}

variable "enable_secrets" {
  description = "Enable Secrets Manager secrets (incurs costs per secret)"
  type        = bool
  default     = false
}

variable "enable_alerting" {
  description = "Enable alerting infrastructure (SNS topics, CloudWatch alarms)"
  type        = bool
  default     = false
}