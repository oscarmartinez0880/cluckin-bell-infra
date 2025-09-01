output "aws_load_balancer_controller_status" {
  description = "Status of AWS Load Balancer Controller deployment"
  value       = var.enable_aws_load_balancer_controller && length(helm_release.aws_load_balancer_controller) > 0 ? helm_release.aws_load_balancer_controller[0].status : null
}

output "cert_manager_status" {
  description = "Status of cert-manager deployment"
  value       = var.enable_cert_manager && length(helm_release.cert_manager) > 0 ? helm_release.cert_manager[0].status : null
}

output "external_dns_status" {
  description = "Status of external-dns deployment"
  value       = var.enable_external_dns && length(helm_release.external_dns) > 0 ? helm_release.external_dns[0].status : null
}

output "cert_manager_namespace" {
  description = "cert-manager namespace"
  value       = var.enable_cert_manager && length(kubernetes_namespace.cert_manager) > 0 ? kubernetes_namespace.cert_manager[0].metadata[0].name : null
}

output "letsencrypt_cluster_issuers" {
  description = "Available Let's Encrypt cluster issuers"
  value       = var.enable_cert_manager ? ["letsencrypt-staging", "letsencrypt-prod"] : []
}

output "argocd_status" {
  description = "Status of Argo CD deployment"
  value       = var.enable_argocd && length(helm_release.argocd) > 0 ? helm_release.argocd[0].status : null
}

output "argocd_namespace" {
  description = "Argo CD namespace"
  value       = var.enable_argocd && length(kubernetes_namespace.argocd) > 0 ? kubernetes_namespace.argocd[0].metadata[0].name : null
}