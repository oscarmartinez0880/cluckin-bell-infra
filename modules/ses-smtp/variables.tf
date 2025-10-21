variable "domain_name" {
  description = "The domain name to verify with SES"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for creating DNS records. If empty, records won't be created."
  type        = string
  default     = ""
}

variable "create_route53_records" {
  description = "Whether to create Route53 DNS records for SES verification and DKIM"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to SES resources"
  type        = map(string)
  default     = {}
}
