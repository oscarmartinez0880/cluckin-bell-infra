output "controller_role_arn" {
  description = "ARN of the IAM role for Karpenter controller"
  value       = aws_iam_role.karpenter_controller.arn
}

output "controller_role_name" {
  description = "Name of the IAM role for Karpenter controller"
  value       = aws_iam_role.karpenter_controller.name
}

output "service_account_name" {
  description = "Name of the Kubernetes service account for Karpenter"
  value       = var.service_account_name
}

output "namespace" {
  description = "Kubernetes namespace where Karpenter is installed"
  value       = var.namespace
}

output "helm_release_name" {
  description = "Name of the Helm release for Karpenter"
  value       = helm_release.karpenter.name
}

output "helm_release_version" {
  description = "Version of the Helm release for Karpenter"
  value       = helm_release.karpenter.version
}
