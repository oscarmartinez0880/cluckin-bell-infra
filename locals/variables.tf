variable "environment" {
  description = "Environment name (dev, qa, prod, devqa)"
  type        = string
  validation {
    condition     = contains(["dev", "qa", "prod", "devqa"], var.environment)
    error_message = "Environment must be one of: dev, qa, prod, devqa."
  }
}