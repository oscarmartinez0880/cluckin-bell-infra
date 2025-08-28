variable "zone_name" {
  description = "Name of the Route53 hosted zone"
  type        = string
}

variable "subdomain_zones" {
  description = "Map of subdomain names to their NS records for delegation"
  type        = map(list(string))
  default     = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}