output "tf_deploy_devqa_role_arn" {
  description = "IAM role ARN for GitHub Actions Terraform deploys (dev/qa)"
  value       = aws_iam_role.tf_deploy_devqa.arn
}