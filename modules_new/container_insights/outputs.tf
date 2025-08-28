output "cloudwatch_log_groups" {
  description = "List of created CloudWatch log groups"
  value = {
    performance = aws_cloudwatch_log_group.container_insights.name
    application = aws_cloudwatch_log_group.application_logs.name
    dataplane   = aws_cloudwatch_log_group.dataplane_logs.name
    host        = aws_cloudwatch_log_group.host_logs.name
  }
}

output "namespace_name" {
  description = "Name of the kubernetes namespace for observability components"
  value       = kubernetes_namespace.amazon_cloudwatch.metadata[0].name
}

output "cloudwatch_agent_enabled" {
  description = "Whether CloudWatch Agent is enabled"
  value       = var.enable_cloudwatch_agent
}

output "fluent_bit_enabled" {
  description = "Whether Fluent Bit is enabled"
  value       = var.enable_fluent_bit
}
