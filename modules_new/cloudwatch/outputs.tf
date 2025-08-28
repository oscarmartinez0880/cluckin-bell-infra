output "log_group_names" {
  description = "Names of the created log groups"
  value       = [for lg in aws_cloudwatch_log_group.main : lg.name]
}

output "log_group_arns" {
  description = "ARNs of the created log groups"
  value       = [for lg in aws_cloudwatch_log_group.main : lg.arn]
}