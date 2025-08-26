output "gha_ecr_push_role_arn" {
  description = "ARN of the GitHub Actions ECR push role"
  value       = aws_iam_role.gha_ecr_push.arn
}

output "gha_eks_deploy_role_arn" {
  description = "ARN of the GitHub Actions EKS deploy role"
  value       = aws_iam_role.gha_eks_deploy.arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = local.github_oidc_arn
}