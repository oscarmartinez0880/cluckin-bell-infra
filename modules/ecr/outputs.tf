output "repository_arns" {
  description = "Full ARNs of the repositories"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.arn }
}

output "repository_urls" {
  description = "URLs of the repositories"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.repository_url }
}

output "registry_ids" {
  description = "Registry IDs of the repositories"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.registry_id }
}

output "repository_names" {
  description = "Names of the repositories"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.name }
}