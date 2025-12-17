# App CI/CD Cheat Sheet (cluckin-bell-app, wingman-api)

Trigger options:
- Push to branches:
  - develop → dev (and often qa)
  - main → prod
- Manual dispatch with environment input (dev|qa|prod)

Build-and-push summary:
- Assumes an AWS role via OIDC
- Logs into ECR
- Builds image once, tags with environment and sha-<commit>, pushes tags
- Argo CD Image Updater handles deployment (no GitOps file edits needed)

Notes:
- Current workflows specify role ARNs inline (not via repository variables). This works if those roles exist with proper GitHub OIDC trust.
- If you prefer centralizing ARNs, define:
  - AWS_ECR_PUSH_ROLE_ARN_NONPROD
  - AWS_ECR_PUSH_ROLE_ARN_PROD
  and reference them via vars.* in the workflow.
