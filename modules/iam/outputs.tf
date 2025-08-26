output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = var.enable_github_oidc ? aws_iam_openid_connect_provider.github[0].arn : null
}

output "irsa_role_arns" {
  description = "ARNs of the IRSA roles"
  value       = { for k, v in aws_iam_role.irsa_roles : k => v.arn }
}

output "irsa_role_names" {
  description = "Names of the IRSA roles"
  value       = { for k, v in aws_iam_role.irsa_roles : k => v.name }
}

output "iam_role_arns" {
  description = "ARNs of the IAM roles"
  value       = { for k, v in aws_iam_role.roles : k => v.arn }
}

output "iam_role_names" {
  description = "Names of the IAM roles"
  value       = { for k, v in aws_iam_role.roles : k => v.name }
}

output "iam_user_arns" {
  description = "ARNs of the IAM users"
  value       = { for k, v in aws_iam_user.users : k => v.arn }
}

output "iam_user_names" {
  description = "Names of the IAM users"
  value       = { for k, v in aws_iam_user.users : k => v.name }
}

output "iam_group_arns" {
  description = "ARNs of the IAM groups"
  value       = { for k, v in aws_iam_group.groups : k => v.arn }
}

output "iam_group_names" {
  description = "Names of the IAM groups"
  value       = { for k, v in aws_iam_group.groups : k => v.name }
}

output "custom_policy_arns" {
  description = "ARNs of the custom IAM policies"
  value       = { for k, v in aws_iam_policy.custom_policies : k => v.arn }
}

output "custom_policy_names" {
  description = "Names of the custom IAM policies"
  value       = { for k, v in aws_iam_policy.custom_policies : k => v.name }
}