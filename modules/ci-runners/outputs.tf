# CI Runners Module Outputs

output "vpc_id" {
  description = "ID of the VPC created for CI runners"
  value       = aws_vpc.ci_runners.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "security_group_id" {
  description = "ID of the security group for CI runners"
  value       = aws_security_group.ci_runners.id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.ci_runner.name
}

output "autoscaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.ci_runner.arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = aws_launch_template.ci_runner.id
}

output "launch_template_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.ci_runner.latest_version
}

output "runner_labels" {
  description = "Labels assigned to the GitHub Actions runners"
  value       = var.runner_labels
}

output "base_ami_id" {
  description = "AMI ID used for the runners"
  value       = data.aws_ami.windows_server_2022.id
}

output "base_ami_name" {
  description = "Name of the AMI used for the runners"
  value       = data.aws_ami.windows_server_2022.name
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile for runners"
  value       = aws_iam_instance_profile.ci_runner.name
}

output "iam_instance_role_arn" {
  description = "ARN of the IAM role for runner instances"
  value       = aws_iam_role.ci_runner_instance.arn
}

output "webhook_endpoint_url" {
  description = "URL of the webhook endpoint (if enabled)"
  value       = var.enable_webhook ? "https://${aws_api_gateway_rest_api.webhook[0].id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.webhook[0].stage_name}/webhook" : null
}

output "webhook_lambda_function_name" {
  description = "Name of the webhook Lambda function (if enabled)"
  value       = var.enable_webhook ? aws_lambda_function.webhook[0].function_name : null
}

# VPC Endpoint information (if enabled)
output "vpc_endpoint_ecr_api_id" {
  description = "ID of the ECR API VPC endpoint (if enabled)"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.ecr_api[0].id : null
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "ID of the ECR DKR VPC endpoint (if enabled)"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.ecr_dkr[0].id : null
}

output "vpc_endpoint_s3_id" {
  description = "ID of the S3 VPC endpoint (if enabled)"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.s3[0].id : null
}