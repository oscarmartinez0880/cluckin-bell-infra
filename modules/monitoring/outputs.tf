output "cloudwatch_log_group_names" {
  description = "Names of the CloudWatch log groups"
  value       = { for k, v in aws_cloudwatch_log_group.log_groups : k => v.name }
}

output "cloudwatch_log_group_arns" {
  description = "ARNs of the CloudWatch log groups"
  value       = { for k, v in aws_cloudwatch_log_group.log_groups : k => v.arn }
}

output "cloudwatch_dashboard_urls" {
  description = "URLs of the CloudWatch dashboards"
  value       = { for k, v in aws_cloudwatch_dashboard.dashboards : k => v.dashboard_url }
}

output "cloudwatch_alarm_arns" {
  description = "ARNs of the CloudWatch metric alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.alarms : k => v.arn }
}

output "cloudwatch_alarm_names" {
  description = "Names of the CloudWatch metric alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.alarms : k => v.alarm_name }
}

output "sns_topic_arns" {
  description = "ARNs of the SNS topics"
  value       = { for k, v in aws_sns_topic.notification_topics : k => v.arn }
}

output "sns_topic_names" {
  description = "Names of the SNS topics"
  value       = { for k, v in aws_sns_topic.notification_topics : k => v.name }
}

output "composite_alarm_arns" {
  description = "ARNs of the CloudWatch composite alarms"
  value       = { for k, v in aws_cloudwatch_composite_alarm.composite_alarms : k => v.arn }
}

output "composite_alarm_names" {
  description = "Names of the CloudWatch composite alarms"
  value       = { for k, v in aws_cloudwatch_composite_alarm.composite_alarms : k => v.alarm_name }
}

output "log_metric_filter_names" {
  description = "Names of the CloudWatch log metric filters"
  value       = { for k, v in aws_cloudwatch_log_metric_filter.metric_filters : k => v.name }
}

output "application_insights_arns" {
  description = "ARNs of the Application Insights applications"
  value       = { for k, v in aws_applicationinsights_application.applications : k => v.arn }
}

output "application_insights_names" {
  description = "Names of the Application Insights applications"
  value       = { for k, v in aws_applicationinsights_application.applications : k => v.resource_group_name }
}