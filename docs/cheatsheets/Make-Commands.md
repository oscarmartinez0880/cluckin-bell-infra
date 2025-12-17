# Make Commands Cheat Sheet (Infra + GitOps)

This summarizes the most common Make targets across repos.

## cluckin-bell-infra

- Auth
  - make login-nonprod
  - make login-prod
  - make check-tools

- Terraform (wrappers)
  - make tf-init ENV=nonprod REGION=us-east-1
  - make tf-plan ENV=nonprod REGION=us-east-1
  - make tf-apply ENV=prod REGION=us-east-1
  - make tf-destroy ENV=nonprod REGION=us-east-1

- EKS lifecycle (eksctl)
  - make eks-create ENV=nonprod REGION=us-east-1
  - make eks-upgrade ENV=prod
  - make eks-delete ENV=nonprod

- Outputs, helpers
  - make outputs ENV=nonprod
  - make outputs-vpc
  - make irsa-nonprod
  - make irsa-prod

- DR helpers
  - make dr-provision-prod REGION=us-west-2
  - make dr-status-prod
  - make dr-enable-features-prod REGION=us-west-2

- Dev/QA operator helpers
  - make ops-up
  - make ops-open
  - make ops-status
  - make ops-down
  - make ops-down-full
  - make ops-down-qa

## cluckin-bell (GitOps)

- Helm lint/render
  - make lint
  - make render-dev
  - make render-qa
  - make render-prod

- Optional (if ARGOCD_SERVER/TOKEN set)
  - make argocd-refresh
