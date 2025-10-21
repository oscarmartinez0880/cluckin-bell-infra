# Terraform CI/CD Workflows

This repository includes workflows for Terraform using GitHub OIDC. Set the per-environment variable in GitHub:

- AWS_TERRAFORM_ROLE_ARN: IAM Role ARN to assume for Terraform plan/apply, scoped per environment (dev, qa, prod).

Wrappers:
- Terraform PR Checks: runs plan on PRs.
- Terraform Deploy: manual workflow to plan/apply on demand.

## Required GitHub permissions

Each job that assumes an AWS role must include:

```yaml
permissions:
  id-token: write
  contents: read
```

## Deploy workflow usage

1. Apply the Terraform in `terraform/accounts/devqa` and `terraform/accounts/prod` to create the OIDC roles:
   - Dev/QA role: `cb-terraform-deploy-devqa` (trusts environments dev and qa)
   - Prod role: `cb-terraform-deploy-prod` (trusts environment prod)

2. Capture the outputs:
   - `tf_deploy_devqa_role_arn`
   - `tf_deploy_prod_role_arn`

3. In GitHub, configure environment variables:
   - Settings → Environments → dev → Variables:
     - `AWS_TERRAFORM_ROLE_ARN = arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa`
   - Settings → Environments → qa → Variables:
     - `AWS_TERRAFORM_ROLE_ARN = arn:aws:iam::264765154707:role/cb-terraform-deploy-devqa`
   - Settings → Environments → prod → Variables:
     - `AWS_TERRAFORM_ROLE_ARN = arn:aws:iam::346746763840:role/cb-terraform-deploy-prod`

4. Run the workflow: Actions → Terraform Deploy → Run workflow.
   - Choose environment (dev/qa/prod)
   - Set `working_directory` to the appropriate environment stack:
     - For dev/qa environments: `working_directory=envs/nonprod`
     - For prod environment: `working_directory=envs/prod`
   - Toggle `apply` to run `terraform apply`
   
   Note: The `var_file` parameter is no longer needed as each environment now has its own terraform.tfvars file.

## GitHub Actions Application Roles

For application-specific GitHub Actions (ECR access, SES notifications), see [GitHub Actions Roles Documentation](github-actions-roles.md) which covers:

- ECR read roles for `cluckin-bell-app` repository
- SES send roles for email notifications
- Environment-scoped permissions and usage examples

## Notes

- Kubernetes versions should remain ≥ 1.34; Terraform version is pinned to 1.13.1 in the workflow.
- Start with AdministratorAccess for bootstrap and reduce privileges once your Terraform scope is stable.
- Trust policies are environment-scoped to align with `environment:` in the job, e.g.,
  - `repo:oscarmartinez0880/cluckin-bell-infra:environment:dev|qa|prod`.
- The github-workflow module is located at repo-root/modules/github-workflow and is optional (controlled by the `manage_github_workflow` variable).