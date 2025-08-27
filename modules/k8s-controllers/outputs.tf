output "aws_load_balancer_controller_status" {
  description = "Status of AWS Load Balancer Controller deployment"
  value       = var.enable_aws_load_balancer_controller ? helm_release.aws_load_balancer_controller[0].status : null
}

output "cert_manager_status" {
  description = "Status of cert-manager deployment"
  value       = var.enable_cert_manager ? helm_release.cert_manager[0].status : null
}

output "external_dns_status" {
  description = "Status of external-dns deployment"
  value       = var.enable_external_dns ? helm_release.external_dns[0].status : null
}

output "cert_manager_namespace" {
  description = "cert-manager namespace"
  value       = var.enable_cert_manager ? kubernetes_namespace.cert_manager[0].metadata[0].name : null
}

output "letsencrypt_cluster_issuers" {
  description = "Available Let's Encrypt cluster issuers"
  value       = var.enable_cert_manager ? ["letsencrypt-staging", "letsencrypt-prod"] : []
}