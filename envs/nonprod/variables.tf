# Variables used by envs/nonprod when loading nonprod.tfvars via -var-file
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
  default = "10.0.0.0/16"
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
  default = "1.30"
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

# Node groups (declared for completeness; wire into modules as needed)
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

# ECR
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