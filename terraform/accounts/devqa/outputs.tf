output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "codecommit_mirror_role_arn" {
  description = "ARN of the IAM role for GitHub→CodeCommit mirroring"
  value       = aws_iam_role.codecommit_mirror.arn
}

output "eks_deploy_role_arns" {
  description = "Map of environment to EKS deploy role ARN"
  value = {
    for env in var.environments : env => aws_iam_role.eks_deploy[env].arn
  }
}

output "ecr_push_role_arns" {
  description = "Map of repository and environment to ECR push role ARN"
  value = {
    for key, role in aws_iam_role.ecr_push : key => role.arn
  }
}

output "ecr_repository_urls" {
  description = "Map of repository name to ECR repository URL"
  value = {
    for repo in var.app_repositories : repo => aws_ecr_repository.repositories[repo].repository_url
  }
}

output "ecr_read_role_arn" {
  description = "ARN of the IAM role for GitHub Actions to read ECR tags for cluckin-bell-app"
  value       = aws_iam_role.ecr_read_cluckin_bell_app.arn
}

output "ses_send_role_arn" {
  description = "ARN of the IAM role for GitHub Actions to send emails via SES in QA environment"
  value       = aws_iam_role.ses_send_cluckin_bell_qa.arn
}

output "account_id" {
  description = "AWS account ID"
  value       = var.account_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}