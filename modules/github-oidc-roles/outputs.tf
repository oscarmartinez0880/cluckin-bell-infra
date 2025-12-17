output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "terraform_role_arn" {
  description = "ARN of the Terraform deployment IAM role"
  value       = aws_iam_role.terraform.arn
}

output "terraform_role_name" {
  description = "Name of the Terraform deployment IAM role"
  value       = aws_iam_role.terraform.name
}

output "eksctl_role_arn" {
  description = "ARN of the eksctl operations IAM role"
  value       = aws_iam_role.eksctl.arn
}

output "eksctl_role_name" {
  description = "Name of the eksctl operations IAM role"
  value       = aws_iam_role.eksctl.name
}

output "ecr_push_role_arn" {
  description = "ARN of the ECR push IAM role"
  value       = aws_iam_role.ecr_push.arn
}

output "ecr_push_role_name" {
  description = "Name of the ECR push IAM role"
  value       = aws_iam_role.ecr_push.name
}
