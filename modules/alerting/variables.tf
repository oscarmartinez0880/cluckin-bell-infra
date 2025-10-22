variable "environment" {
  description = "Environment name (e.g., nonprod, prod)"
  type        = string
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "alert_phone" {
  description = "Phone number for SMS alert notifications (E.164 format, e.g., +12298051449)"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days for Lambda function"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
