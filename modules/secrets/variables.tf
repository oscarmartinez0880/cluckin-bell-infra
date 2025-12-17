variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    description      = string
    static_values    = map(string)
    generated_values = map(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_replication" {
  description = "Enable replication of secrets to other regions"
  type        = bool
  default     = false
}

variable "replication_regions" {
  description = "List of AWS regions to replicate secrets to"
  type        = list(string)
  default     = []
}