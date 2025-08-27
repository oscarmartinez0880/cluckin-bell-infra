output "mirror_role_arn" {
  description = "IAM role ARN for GitHub Actions to mirror to CodeCommit"
  value       = aws_iam_role.github_mirror.arn
}