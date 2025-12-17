# GitHub Actions Cheat Sheet

All workflows use GitHub OIDC (no access keys). Ensure repository variables for role ARNs are set to match workflow inputs.

Infra repository:
- Infrastructure Terraform
  - Inputs: environment (nonprod|prod), action (plan|apply|destroy), region (default us-east-1)
  - Variables used:
    - Nonprod: AWS_TERRAFORM_ROLE_ARN_NONPROD
    - Prod:    AWS_TERRAFORM_ROLE_ARN_PROD

- eksctl Cluster Ops
  - Inputs: environment (nonprod|prod), operation (create|upgrade|delete), region
  - Variables typically used:
    - AWS_EKSCTL_ROLE_ARN_NONPROD
    - AWS_EKSCTL_ROLE_ARN_PROD

- DR: Launch Prod in Alternate Region
  - Inputs: region (e.g., us-west-2)
  - Variables used:
    - AWS_TERRAFORM_ROLE_ARN_PROD

GitOps repository:
- gitops-validate / helm-lint run on PRs and pushes to main/develop/staging.

Apps (frontend and API):
- Build-and-push workflows use OIDC to push to account ECRs.
- Current state: role ARNs may be specified inline in the workflow; ensure those roles exist and trust GitHub OIDC. Optionally migrate to repo variables later.
