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
    name   = string
    create = bool
    vpc_id = string
  })
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