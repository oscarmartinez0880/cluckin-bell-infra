output "workflow_file_created" {
  description = "Whether the GitHub workflow file was created"
  value       = var.manage_github_workflow ? github_repository_file.mirror_workflow[0].id : null
}