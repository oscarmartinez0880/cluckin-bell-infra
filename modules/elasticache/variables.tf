variable "cluster_id" {
  description = "The cluster identifier"
  type        = string
}

variable "description" {
  description = "The description of the replication group"
  type        = string
  default     = "Managed by Terraform"
}

variable "engine" {
  description = "The name of the cache engine to be used (redis or memcached)"
  type        = string
  default     = "redis"
  validation {
    condition     = contains(["redis", "memcached"], var.engine)
    error_message = "Engine must be either redis or memcached."
  }
}

variable "engine_version" {
  description = "The version number of the cache engine"
  type        = string
  default     = "7.0"
}

variable "family" {
  description = "The family of the ElastiCache parameter group"
  type        = string
  default     = "redis7.x"
}

variable "node_type" {
  description = "The instance class used"
  type        = string
  default     = "cache.t3.micro"
}

variable "port" {
  description = "The port number on which each of the cache nodes will accept connections"
  type        = number
  default     = 6379
}

variable "num_cache_clusters" {
  description = "The number of cache clusters (primary and replicas) this replication group will have"
  type        = number
  default     = 2
}

variable "num_cache_nodes" {
  description = "The initial number of cache nodes that the cache cluster will have (for Memcached)"
  type        = number
  default     = 1
}

variable "automatic_failover_enabled" {
  description = "Specifies whether a read-only replica will be automatically promoted to read/write primary if the existing primary fails"
  type        = bool
  default     = true
}

variable "multi_az_enabled" {
  description = "Specifies whether to enable Multi-AZ Support for the replication group"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "The VPC ID where the ElastiCache cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of VPC subnet IDs for the cache subnet group"
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "List of security group IDs that are allowed to access the ElastiCache cluster"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks that are allowed to access the ElastiCache cluster"
  type        = list(string)
  default     = []
}

variable "snapshot_retention_limit" {
  description = "The number of days for which ElastiCache will retain automatic cache cluster snapshots"
  type        = number
  default     = 5
}

variable "snapshot_window" {
  description = "The daily time range during which automated backups are created"
  type        = string
  default     = "03:00-05:00"
}

variable "final_snapshot_identifier" {
  description = "The name of your final cluster snapshot"
  type        = string
  default     = null
}

variable "maintenance_window" {
  description = "The weekly time range for when maintenance on the cache cluster is performed"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "auto_minor_version_upgrade" {
  description = "Specifies whether minor version engine upgrades will be applied automatically to the underlying Cache Cluster instances during the maintenance window"
  type        = bool
  default     = true
}

variable "at_rest_encryption_enabled" {
  description = "Whether to enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Whether to enable encryption in transit"
  type        = bool
  default     = true
}

variable "auth_token" {
  description = "The password used to access a password protected server"
  type        = string
  default     = null
  sensitive   = true
}

variable "create_parameter_group" {
  description = "Whether to create a parameter group"
  type        = bool
  default     = true
}

variable "parameter_group_name" {
  description = "The name of the parameter group to associate with this cache cluster"
  type        = string
  default     = null
}

variable "parameters" {
  description = "A list of ElastiCache parameters to apply"
  type        = list(map(string))
  default     = []
}

variable "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for ElastiCache logs"
  type        = string
  default     = null
}

variable "cloudwatch_log_group_retention_in_days" {
  description = "The number of days to retain CloudWatch logs for the ElastiCache cluster"
  type        = number
  default     = 7
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}