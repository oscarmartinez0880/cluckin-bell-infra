output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.eks_scaler.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.eks_scaler.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

output "scale_up_schedule_arn" {
  description = "ARN of the scale-up schedule"
  value       = aws_scheduler_schedule.scale_up.arn
}

output "scale_up_schedule_expression" {
  description = "Cron expression for scale-up schedule"
  value       = aws_scheduler_schedule.scale_up.schedule_expression
}

output "scale_down_schedule_arn" {
  description = "ARN of the scale-down schedule"
  value       = aws_scheduler_schedule.scale_down.arn
}

output "scale_down_schedule_expression" {
  description = "Cron expression for scale-down schedule"
  value       = aws_scheduler_schedule.scale_down.schedule_expression
}

output "manual_invoke_scale_up" {
  description = "AWS CLI command to manually scale up"
  value       = "aws --profile ${var.profile} lambda invoke --function-name ${aws_lambda_function.eks_scaler.function_name} --payload '{\"action\":\"scale_up\"}' /dev/stdout"
}

output "manual_invoke_scale_down" {
  description = "AWS CLI command to manually scale down"
  value       = "aws --profile ${var.profile} lambda invoke --function-name ${aws_lambda_function.eks_scaler.function_name} --payload '{\"action\":\"scale_down\"}' /dev/stdout"
}

output "check_nodegroup_command" {
  description = "AWS CLI command to check nodegroup status"
  value       = "aws --profile ${var.profile} eks describe-nodegroup --cluster-name ${var.cluster_name} --nodegroup-name ${var.nodegroups[0]} --query 'nodegroup.scalingConfig'"
}
