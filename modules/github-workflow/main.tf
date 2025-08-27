terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

# GitHub repository file for CodeCommit mirroring workflow
resource "github_repository_file" "mirror_workflow" {
  count      = var.manage_github_workflow ? 1 : 0
  repository = var.repository_name
  branch     = "main"
  file       = ".github/workflows/mirror-to-codecommit.yml"

  content = yamlencode({
    name = "Mirror to CodeCommit"

    on = {
      push = {
        branches = ["main"]
      }
    }

    permissions = {
      id-token = "write"
      contents = "read"
    }

    jobs = {
      mirror = {
        name    = "Mirror to CodeCommit"
        runs-on = "ubuntu-latest"

        steps = [
          {
            name = "Checkout"
            uses = "actions/checkout@v4"
            with = {
              fetch-depth = 0 # Full history for mirror
            }
          },
          {
            name = "Configure AWS credentials"
            uses = "aws-actions/configure-aws-credentials@v4"
            with = {
              role-to-assume    = var.codecommit_mirror_role_arn
              aws-region        = "us-east-1"
              role-session-name = "GitHubActions-CodeCommitMirror"
            }
          },
          {
            name = "Mirror to CodeCommit"
            run  = "git push --mirror codecommit::us-east-1://cluckin-bell"
          }
        ]
      }
    }
  })

  commit_message = "Add CodeCommit mirroring workflow"
  commit_author  = var.commit_author
  commit_email   = var.commit_email
}