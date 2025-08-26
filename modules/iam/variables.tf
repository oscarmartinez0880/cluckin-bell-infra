variable "name_prefix" {
  description = "Prefix for all IAM resource names"
  type        = string
}

variable "enable_github_oidc" {
  description = "Whether to create GitHub OIDC provider"
  type        = bool
  default     = false
}

variable "irsa_roles" {
  description = "Map of IRSA roles to create"
  type = map(object({
    oidc_provider_arn = string
    namespace         = string
    service_account   = string
    policy_arns       = optional(list(string), [])
    custom_policies   = optional(map(string), {})
  }))
  default = {}
}

variable "iam_roles" {
  description = "Map of IAM roles to create"
  type = map(object({
    assume_role_policy = string
    policy_arns        = optional(list(string), [])
    inline_policies    = optional(map(string), {})
    path               = optional(string, "/")
  }))
  default = {}
}

variable "iam_users" {
  description = "Map of IAM users to create"
  type = map(object({
    policy_arns = optional(list(string), [])
    path        = optional(string, "/")
  }))
  default = {}
}

variable "iam_groups" {
  description = "Map of IAM groups to create"
  type = map(object({
    policy_arns = optional(list(string), [])
    users       = optional(list(string), [])
    path        = optional(string, "/")
  }))
  default = {}
}

variable "custom_policies" {
  description = "Map of custom IAM policies to create"
  type = map(object({
    policy_document = string
    description     = optional(string, "Custom policy managed by Terraform")
    path            = optional(string, "/")
  }))
  default = {}
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}