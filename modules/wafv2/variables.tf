variable "name_prefix" {
  description = "Name prefix for WAF resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "enable_bot_control" {
  description = "Enable Bot Control managed rule group"
  type        = bool
  default     = false
}

variable "api_rate_limit" {
  description = "Rate limit for /api paths (requests per 5 minutes)"
  type        = number
  default     = 2000
}

variable "geo_block_countries" {
  description = "List of country codes to block (ISO 3166-1 alpha-2)"
  type        = list(string)
  default     = []
}

variable "admin_ip_allow_cidrs" {
  description = "List of CIDR blocks allowed to access admin paths"
  type        = list(string)
  default     = []
}

variable "enable_logging" {
  description = "Enable WAF request logging to CloudWatch"
  type        = bool
  default     = false
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
