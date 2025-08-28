variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "dev_zone_name_servers" {
  description = "Name servers for dev.cluckn-bell.com zone (from nonprod account)"
  type        = list(string)
}

variable "qa_zone_name_servers" {
  description = "Name servers for qa.cluckn-bell.com zone (from nonprod account)"
  type        = list(string)
}