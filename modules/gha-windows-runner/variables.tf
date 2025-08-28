variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.xlarge"
}

variable "github_owner" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_pat_ssm_parameter_name" {
  type = string
}

variable "runner_labels" {
  type    = list(string)
  default = ["self-hosted", "windows", "x64", "windows-containers"]
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "root_volume_size" {
  type    = number
  default = 100
}