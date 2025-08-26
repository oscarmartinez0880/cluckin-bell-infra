variable "repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = []
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "encryption_type" {
  description = "The encryption type to use for the repository (AES256 or KMS)"
  type        = string
  default     = "AES256"
  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "Encryption type must be either AES256 or KMS."
  }
}

variable "kms_key" {
  description = "The KMS key to use when encryption_type is KMS"
  type        = string
  default     = null
}

variable "enable_lifecycle_policy" {
  description = "Whether to enable lifecycle policy"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Maximum number of images to keep"
  type        = number
  default     = 10
}

variable "untagged_image_days" {
  description = "Number of days to keep untagged images"
  type        = number
  default     = 1
}

variable "enable_cross_account_access" {
  description = "Whether to enable cross-account access"
  type        = bool
  default     = false
}

variable "cross_account_principals" {
  description = "List of AWS principals for cross-account access"
  type        = list(string)
  default     = []
}

variable "enable_replication" {
  description = "Whether to enable ECR replication"
  type        = bool
  default     = false
}

variable "replication_region" {
  description = "Region for ECR replication"
  type        = string
  default     = "us-west-2"
}

variable "replication_filter" {
  description = "Filter for ECR replication"
  type        = string
  default     = ""
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}