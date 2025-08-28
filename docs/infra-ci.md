# Terraform CI/CD Workflows

This repository includes reusable workflows for Terraform. Set the following repository secret:

- AWS_TERRAFORM_ROLE_ARN: IAM Role ARN trusted by GitHub OIDC with permissions to plan/apply.

Wrappers:
- Terraform PR Checks: runs plan on PRs.
- Terraform Dev/QA/Prod: plans on push; to apply, manually run the workflow with apply=true. Dev/QA/Prod map to develop/staging/main branches.

Inputs to adjust:
- working_directory: where your Terraform lives (default ".").
- var_file: set to per-environment tfvars if you use them (e.g., env/dev.tfvars).

Security: tfsec runs on PRs. Review results in Security > Code scanning alerts.