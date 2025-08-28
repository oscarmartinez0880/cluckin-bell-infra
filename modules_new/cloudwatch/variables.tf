variable "log_groups" {
  description = "Map of log group names and their configurations"
  type        = map(string)
  default     = {}
}

variable "retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 1
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}