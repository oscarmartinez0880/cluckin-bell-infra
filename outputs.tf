# Core infrastructure outputs
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "project_name" {
  description = "Project name"
  value       = var.project_name
}

# CI Runners outputs
output "ci_runners_autoscaling_group_name" {
  description = "Name of the CI runners Auto Scaling Group"
  value       = var.enable_ci_runners ? module.ci_runners[0].autoscaling_group_name : null
}

output "ci_runners_labels" {
  description = "Labels assigned to the GitHub Actions runners"
  value       = var.enable_ci_runners ? module.ci_runners[0].runner_labels : null
}

output "ci_runners_base_ami_id" {
  description = "AMI ID used for the CI runners"
  value       = var.enable_ci_runners ? module.ci_runners[0].base_ami_id : null
}

output "ci_runners_webhook_endpoint_url" {
  description = "URL of the webhook endpoint (if enabled)"
  value       = var.enable_ci_runners ? module.ci_runners[0].webhook_endpoint_url : null
}

# TODO: Add outputs for your infrastructure resources
# Examples:

# AWS outputs
# output "vpc_id" {
#   description = "ID of the VPC"
#   value       = aws_vpc.main.id
# }

# output "eks_cluster_name" {
#   description = "EKS cluster name"
#   value       = aws_eks_cluster.main.name
# }

# Azure outputs
# output "resource_group_name" {
#   description = "Resource group name"
#   value       = azurerm_resource_group.main.name
# }

# GCP outputs
# output "gke_cluster_name" {
#   description = "GKE cluster name"
#   value       = google_container_cluster.main.name
# }