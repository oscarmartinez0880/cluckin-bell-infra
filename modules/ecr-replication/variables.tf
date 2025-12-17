variable "replication_regions" {
  description = "List of AWS regions to replicate ECR images to"
  type        = list(string)
  default     = []
}
