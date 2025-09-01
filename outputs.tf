output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

# Linux node group outputs
output "linux_node_group_id" {
  description = "EKS Linux node group ID"
  value       = module.eks.eks_managed_node_groups["linux"].node_group_id
}

output "linux_node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Linux Node Group"
  value       = module.eks.eks_managed_node_groups["linux"].node_group_arn
}

output "linux_node_group_role_arn" {
  description = "Amazon Resource Name (ARN) of the IAM role for Linux node group"
  value       = module.eks.eks_managed_node_groups["linux"].iam_role_arn
}

# Windows node group outputs
output "windows_node_group_id" {
  description = "EKS Windows node group ID"
  value       = module.eks.eks_managed_node_groups["windows"].node_group_id
}

output "windows_node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Windows Node Group"
  value       = module.eks.eks_managed_node_groups["windows"].node_group_arn
}

output "windows_node_group_role_arn" {
  description = "Amazon Resource Name (ARN) of the IAM role for Windows node group"
  value       = module.eks.eks_managed_node_groups["windows"].iam_role_arn
}

# Cluster access
output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_token" {
  description = "Token to use to authenticate with the cluster"
  value       = data.aws_eks_cluster_auth.cluster.token
  sensitive   = true
}

# KMS key
output "kms_key_arn" {
  description = "The Amazon Resource Name (ARN) of the KMS key for EKS encryption"
  value       = aws_kms_key.eks.arn
}

# Data source for cluster auth
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# ECR outputs
output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value = {
    for repo in var.ecr_repositories : repo => aws_ecr_repository.repos[repo].repository_url
  }
}

output "ecr_repository_arns" {
  description = "Map of ECR repository ARNs"
  value = {
    for repo in var.ecr_repositories : repo => aws_ecr_repository.repos[repo].arn
  }
}

# DNS/TLS Controller outputs
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IRSA role"
  value       = module.aws_load_balancer_controller_irsa.iam_role_arn
}

output "cert_manager_role_arn" {
  description = "ARN of the cert-manager IRSA role"
  value       = module.cert_manager_irsa.iam_role_arn
}

output "external_dns_role_arn" {
  description = "ARN of the external-dns IRSA role"
  value       = module.external_dns_irsa.iam_role_arn
}

output "k8s_controllers_status" {
  description = "Status of deployed Kubernetes controllers"
  value = {
    aws_load_balancer_controller = module.k8s_controllers.aws_load_balancer_controller_status
    cert_manager                 = module.k8s_controllers.cert_manager_status
    external_dns                 = module.k8s_controllers.external_dns_status
  }
}

output "letsencrypt_cluster_issuers" {
  description = "Available Let's Encrypt cluster issuers"
  value       = module.k8s_controllers.letsencrypt_cluster_issuers
}

output "domains" {
  description = "Configured domains for the environment"
  value = {
    frontend = local.domains.frontend[var.environment]
    api      = local.domains.api[var.environment]
  }
}

# Route53 outputs
output "public_hosted_zone_id" {
  description = "Route53 public hosted zone ID for cluckn-bell.com"
  value       = var.manage_route53 && length(aws_route53_zone.public) > 0 ? aws_route53_zone.public[0].zone_id : null
}

output "public_hosted_zone_name_servers" {
  description = "Name servers for the public hosted zone"
  value       = var.manage_route53 && length(aws_route53_zone.public) > 0 ? aws_route53_zone.public[0].name_servers : null
}

output "private_hosted_zone_id" {
  description = "Route53 private hosted zone ID for cluckn-bell.com"
  value       = var.manage_route53 && length(aws_route53_zone.private) > 0 ? aws_route53_zone.private[0].zone_id : null
}
# Argo CD outputs
output "argocd_url" {
  description = "Argo CD server URL"
  value       = "https://argocd.${var.environment == "prod" ? "cluckn-bell.com" : "${var.environment}.cluckn-bell.com"}"
}

output "argocd_kubectl_port_forward_command" {
  description = "kubectl port-forward command for local Argo CD access"
  value       = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}

# CodeCommit outputs
output "codecommit_repository_name" {
  description = "Name of the CodeCommit repository for GitOps"
  value       = aws_codecommit_repository.cluckin_bell.repository_name
}

output "codecommit_repository_arn" {
  description = "ARN of the CodeCommit repository"
  value       = aws_codecommit_repository.cluckin_bell.arn
}

output "codecommit_repository_clone_url_ssh" {
  description = "SSH clone URL for the CodeCommit repository"
  value       = aws_codecommit_repository.cluckin_bell.clone_url_ssh
}

output "codecommit_repository_clone_url_https" {
  description = "HTTPS clone URL for the CodeCommit repository"
  value       = aws_codecommit_repository.cluckin_bell.clone_url_http
}

output "argocd_repo_server_role_arn" {
  description = "ARN of the Argo CD repo-server IRSA role"
  value       = module.argocd_repo_server_irsa.iam_role_arn
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
