variable "enable_ecr_replication" {
  description = "Enable ECR cross-region replication for disaster recovery"
  type        = bool
  default     = false
}

variable "ecr_replication_regions" {
  description = "List of AWS regions to replicate ECR images to"
  type        = list(string)
  default     = []
}

variable "enable_secrets_replication" {
  description = "Enable Secrets Manager replication for disaster recovery"
  type        = bool
  default     = false
}

variable "secrets_replication_regions" {
  description = "List of AWS regions to replicate secrets to"
  type        = list(string)
  default     = []
}

variable "secret_ids" {
  description = "List of Secret IDs to replicate (ARNs or names)"
  type        = list(string)
  default     = []
}

variable "enable_dns_failover" {
  description = "Enable Route53 DNS failover for disaster recovery"
  type        = bool
  default     = false
}

variable "failover_records" {
  description = "Map of DNS failover records with primary and secondary endpoints"
  type = map(object({
    name               = string
    type               = string
    primary_endpoint   = string
    secondary_endpoint = string
    health_check_path  = optional(string, "/health")
  }))
  default = {}
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for failover records"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to DR resources"
  type        = map(string)
  default     = {}
}
