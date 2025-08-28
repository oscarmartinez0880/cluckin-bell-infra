output "tf_deploy_prod_role_arn" {
  description = "IAM role ARN for GitHub Actions Terraform deploys (prod)"
  value       = aws_iam_role.tf_deploy_prod.arn
}