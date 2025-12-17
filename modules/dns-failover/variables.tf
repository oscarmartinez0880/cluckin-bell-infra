variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for failover records"
  type        = string
}

variable "failover_records" {
  description = "Map of DNS failover records with primary and secondary endpoints"
  type = map(object({
    hostname           = string
    primary_endpoint   = string
    secondary_endpoint = string
    health_check_path  = string
    health_check_port  = number
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
