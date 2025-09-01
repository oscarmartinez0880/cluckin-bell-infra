output "web_acl_arn" {
  description = "ARN of the WAF WebACL"
  value       = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  description = "ID of the WAF WebACL"
  value       = aws_wafv2_web_acl.main.id
}

output "web_acl_name" {
  description = "Name of the WAF WebACL"
  value       = aws_wafv2_web_acl.main.name
}

output "ip_set_admin_arn" {
  description = "ARN of the admin IP allowlist IP set"
  value       = length(aws_wafv2_ip_set.admin_allowlist) > 0 ? aws_wafv2_ip_set.admin_allowlist[0].arn : null
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for WAF logs"
  value       = length(aws_cloudwatch_log_group.waf) > 0 ? aws_cloudwatch_log_group.waf[0].name : null
}
