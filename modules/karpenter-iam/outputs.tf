output "controller_role_arn" {
  description = "ARN of the Karpenter controller IAM role"
  value       = aws_iam_role.karpenter_controller.arn
}

output "controller_role_name" {
  description = "Name of the Karpenter controller IAM role"
  value       = aws_iam_role.karpenter_controller.name
}

output "node_role_arn" {
  description = "ARN of the Karpenter node IAM role"
  value       = aws_iam_role.karpenter_node.arn
}

output "node_role_name" {
  description = "Name of the Karpenter node IAM role"
  value       = aws_iam_role.karpenter_node.name
}

output "instance_profile_name" {
  description = "Name of the Karpenter instance profile"
  value       = aws_iam_instance_profile.karpenter.name
}

output "instance_profile_arn" {
  description = "ARN of the Karpenter instance profile"
  value       = aws_iam_instance_profile.karpenter.arn
}

output "queue_name" {
  description = "Name of the SQS queue for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter.name
}

output "queue_arn" {
  description = "ARN of the SQS queue for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter.arn
}
