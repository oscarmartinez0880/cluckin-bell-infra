variable "region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS CLI profile to use for authentication"
  type        = string
  default     = "cluckin-bell-qa"
}

variable "cluster_name" {
  description = "Name of the EKS cluster to scale"
  type        = string
  default     = "cb-use1-shared"
}

variable "nodegroups" {
  description = "List of nodegroup names to scale"
  type        = list(string)
  default     = ["default"]
}

variable "scale_up_min_size" {
  description = "Minimum size during daytime hours"
  type        = number
  default     = 2
}

variable "scale_up_desired_size" {
  description = "Desired size during daytime hours"
  type        = number
  default     = 2
}

variable "scale_up_max_size" {
  description = "Maximum size during daytime hours"
  type        = number
  default     = 5
}

variable "scale_down_min_size" {
  description = "Minimum size during off-hours"
  type        = number
  default     = 0
}

variable "scale_down_desired_size" {
  description = "Desired size during off-hours"
  type        = number
  default     = 0
}

variable "scale_down_max_size" {
  description = "Maximum size during off-hours"
  type        = number
  default     = 0
}

variable "timezone" {
  description = "Timezone for the schedules"
  type        = string
  default     = "America/New_York"
}

variable "scale_up_cron" {
  description = "Cron expression for scaling up (EventBridge format)"
  type        = string
  default     = "cron(0 8 ? * MON-FRI *)"
}

variable "scale_down_cron" {
  description = "Cron expression for scaling down (EventBridge format)"
  type        = string
  default     = "cron(0 21 ? * MON-FRI *)"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 300
}

variable "wait_for_active" {
  description = "Whether Lambda should wait for nodegroups to reach ACTIVE status"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "cluckn-bell"
    Environment = "devqa"
    ManagedBy   = "terraform"
  }
}
