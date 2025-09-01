variable "user_pool_name" {
  description = "Name of the Cognito user pool"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the Cognito user pool"
  type        = string
}

variable "clients" {
  description = "Map of client configurations"
  type = map(object({
    callback_urls = list(string)
    logout_urls   = list(string)
  }))
  default = {}
}

variable "admin_user_emails" {
  description = "List of admin user email addresses to create"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}