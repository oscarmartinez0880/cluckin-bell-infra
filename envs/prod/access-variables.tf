variable "sso_admin_role_arn" {
  description = "IAM Role ARN for the SSO Admin role to grant cluster-admin (optional)"
  type        = string
  default     = ""
}