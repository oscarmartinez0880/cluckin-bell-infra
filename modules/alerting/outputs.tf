output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.alerts.name
}

output "webhook_url" {
  description = "Alertmanager webhook URL (API Gateway endpoint)"
  value       = "${aws_apigatewayv2_api.webhook.api_endpoint}/webhook"
}

output "webhook_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the webhook URL"
  value       = aws_secretsmanager_secret.webhook_url.arn
}

output "webhook_secret_name" {
  description = "Name of the Secrets Manager secret containing the webhook URL"
  value       = aws_secretsmanager_secret.webhook_url.name
}

output "lambda_function_name" {
  description = "Name of the Lambda function handling webhooks"
  value       = aws_lambda_function.alertmanager_webhook.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.alertmanager_webhook.arn
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.webhook.id
}
