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