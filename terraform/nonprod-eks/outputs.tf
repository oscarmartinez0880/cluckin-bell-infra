output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Identity Provider"
  value       = module.eks.oidc_provider_arn
}

output "node_group_names" {
  description = "List of EKS managed node group names"
  value       = [for ng in module.eks.eks_managed_node_groups : ng.node_group_id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by the cluster"
  value       = var.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the cluster"
  value       = var.public_subnet_ids
}

output "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  value       = var.vpc_id
}