variable "public_zone" {
  description = "Configuration for public Route53 zone"
  type = object({
    name   = string
    create = bool
  })
}

variable "private_zone" {
  description = "Configuration for private Route53 zone"
  type = object({
    name    = string
    create  = bool
    vpc_id  = string
    zone_id = optional(string, null)
  })
}

variable "existing_private_zone_id" {
  description = "Existing private hosted zone ID (preferred over name-based lookup)"
  type        = string
  default     = ""
}

variable "subdomain_zones" {
  description = "Map of subdomain names to their NS records for delegation"
  type        = map(list(string))
  default     = {}
}

variable "certificates" {
  description = "Map of certificates to create"
  type = map(object({
    domain_name               = string
    subject_alternative_names = list(string)
    use_private_zone          = bool
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}