output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC identity provider"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc_provider_url" {
  description = "URL of the IAM OIDC identity provider"
  value       = aws_iam_openid_connect_provider.cluster.url
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = module.aws_load_balancer_controller_irsa.iam_role_arn
}

output "aws_load_balancer_controller_role_name" {
  description = "Name of the IAM role for AWS Load Balancer Controller"
  value       = module.aws_load_balancer_controller_irsa.iam_role_name
}

output "external_dns_role_arn" {
  description = "ARN of the IAM role for External DNS"
  value       = module.external_dns_irsa.iam_role_arn
}

output "external_dns_role_name" {
  description = "Name of the IAM role for External DNS"
  value       = module.external_dns_irsa.iam_role_name
}

output "cert_manager_role_arn" {
  description = "ARN of the IAM role for Cert Manager"
  value       = module.cert_manager_irsa.iam_role_arn
}

output "cert_manager_role_name" {
  description = "Name of the IAM role for Cert Manager"
  value       = module.cert_manager_irsa.iam_role_name
}

# Convenience outputs for Helm values
output "helm_values" {
  description = "Helm values snippet for deploying controllers with these IAM roles"
  value = <<-EOT
    # AWS Load Balancer Controller
    aws-load-balancer-controller:
      serviceAccount:
        annotations:
          eks.amazonaws.com/role-arn: ${module.aws_load_balancer_controller_irsa.iam_role_arn}
    
    # External DNS
    external-dns:
      serviceAccount:
        annotations:
          eks.amazonaws.com/role-arn: ${module.external_dns_irsa.iam_role_arn}
    
    # Cert Manager
    cert-manager:
      serviceAccount:
        annotations:
          eks.amazonaws.com/role-arn: ${module.cert_manager_irsa.iam_role_arn}
  EOT
}
