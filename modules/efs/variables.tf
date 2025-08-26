variable "name" {
  description = "Name of the EFS file system"
  type        = string
}

variable "creation_token" {
  description = "A unique name (a maximum of 64 characters) used as reference when creating the Elastic File System"
  type        = string
  default     = null
}

variable "performance_mode" {
  description = "The file system performance mode"
  type        = string
  default     = "generalPurpose"
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "Performance mode must be either generalPurpose or maxIO."
  }
}

variable "throughput_mode" {
  description = "Throughput mode for the file system"
  type        = string
  default     = "bursting"
  validation {
    condition     = contains(["bursting", "provisioned"], var.throughput_mode)
    error_message = "Throughput mode must be either bursting or provisioned."
  }
}

variable "encrypted" {
  description = "If true, the disk will be encrypted"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key"
  type        = string
  default     = null
}

variable "lifecycle_policy" {
  description = "A file system lifecycle policy object"
  type = object({
    transition_to_ia                    = optional(string)
    transition_to_primary_storage_class = optional(string)
  })
  default = null
}

variable "enable_backup_policy" {
  description = "A boolean that indicates whether automatic backups are enabled"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "ID of the VPC where to create security group"
  type        = string
}

variable "subnet_ids" {
  description = "A list of VPC subnet IDs for mount targets"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "List of security group IDs that are allowed to access the EFS"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks that are allowed to access the EFS"
  type        = list(string)
  default     = []
}

variable "access_points" {
  description = "A map of access point definitions to create"
  type = map(object({
    posix_user = optional(object({
      gid            = number
      uid            = number
      secondary_gids = optional(list(number))
    }))
    root_directory = optional(object({
      path = optional(string)
      creation_info = optional(object({
        owner_gid   = number
        owner_uid   = number
        permissions = string
      }))
    }))
  }))
  default = {}
}

variable "policy" {
  description = "A valid JSON formatted policy for the EFS file system"
  type        = string
  default     = null
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}