output "user_pool_id" {
  description = "ID of the Cognito user pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito user pool"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_endpoint" {
  description = "Endpoint name of the user pool"
  value       = aws_cognito_user_pool.main.endpoint
}

output "user_pool_domain" {
  description = "Domain name of the user pool"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "client_ids" {
  description = "Map of client names to client IDs"
  value       = { for k, v in aws_cognito_user_pool_client.clients : k => v.id }
}

output "client_secrets" {
  description = "Map of client names to client secrets"
  value       = { for k, v in aws_cognito_user_pool_client.clients : k => v.client_secret }
  sensitive   = true
}