output "application_name" {
  description = "Name of the ArgoCD application"
  value       = kubernetes_manifest.cluckin_bell_application.manifest.metadata.name
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed"
  value       = var.namespace
}

output "server_url" {
  description = "ArgoCD server URL (LoadBalancer endpoint)"
  value       = try(data.kubernetes_service.argocd_server.status.0.load_balancer.0.ingress.0.hostname, "pending")
}

output "helm_release_status" {
  description = "Status of the ArgoCD Helm release"
  value       = helm_release.argocd.status
}