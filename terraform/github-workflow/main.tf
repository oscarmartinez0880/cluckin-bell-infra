terraform {
  required_version = ">= 1.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 5.0"
    }
  }
}

# Uses GITHUB_TOKEN from environment
provider "github" {}

# Conditionally manage the workflow file
resource "github_repository_file" "mirror_workflow" {
  count               = var.manage_github_workflow ? 1 : 0
  repository          = var.app_repo_name
  branch              = "main"
  file                = ".github/workflows/mirror-to-codecommit.yml"
  commit_message      = "chore(ci): manage CodeCommit mirror workflow via Terraform"
  overwrite_on_create = true

  content = templatefile("${path.module}/templates/mirror-to-codecommit.yml.tmpl", {
    aws_region            = var.aws_region
    mirror_role_arn_devqa = var.mirror_role_arn_devqa
    mirror_role_arn_prod  = var.mirror_role_arn_prod
    repo_name             = var.codecommit_repo_name
  })
}