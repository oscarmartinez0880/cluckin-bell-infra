variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "enable_cloudwatch_agent" {
  description = "Enable CloudWatch Agent for metrics collection"
  type        = bool
  default     = true
}

variable "enable_fluent_bit" {
  description = "Enable Fluent Bit for log collection"
  type        = bool
  default     = true
}

variable "cloudwatch_agent_version" {
  description = "Version of CloudWatch Agent Helm chart"
  type        = string
  default     = "0.0.9"
}

variable "fluent_bit_version" {
  description = "Version of AWS for Fluent Bit Helm chart"
  type        = string
  default     = "0.1.32"
}

variable "cloudwatch_agent_role_arn" {
  description = "IAM role ARN for CloudWatch Agent"
  type        = string
}

variable "fluent_bit_role_arn" {
  description = "IAM role ARN for Fluent Bit"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "A map of tags to assign to the resources"
  type        = map(string)
  default     = {}
}
