output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = try(module.eks[0].cluster_name, null)
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = try(module.eks[0].cluster_endpoint, null)
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = try(module.eks[0].cluster_security_group_id, null)
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = try(module.eks[0].cluster_iam_role_name, null)
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = try(module.eks[0].cluster_certificate_authority_data, null)
  sensitive   = true
}

output "vpc_id" {
  description = "ID of the VPC where the cluster and workers are deployed"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "node_groups" {
  description = "EKS node groups"
  value       = try(module.eks[0].eks_managed_node_groups, {})
}

output "namespace" {
  description = "Kubernetes namespace for cluckin-bell"
  value       = local.namespace
}

output "argocd_application_name" {
  description = "Name of the ArgoCD application"
  value       = try(module.argocd[0].application_name, null)
}

output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = try(module.argocd[0].server_url, null)
}