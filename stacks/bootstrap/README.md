# Bootstrap Stack

This stack creates the foundational GitHub OIDC IAM roles required for CI/CD operations from the cluckin-bell-app repository.

## Resources Created

### GitHub OIDC Provider
- Creates or uses existing GitHub OIDC provider for AWS authentication
- Configured with proper thumbprints for security

### IAM Roles

#### gha-ecr-push
- **Purpose**: Allows GitHub Actions from `oscarmartinez0880/cluckin-bell-app` to push Docker images to ECR
- **Permissions**: 
  - `ecr:GetAuthorizationToken` (global)
  - ECR push permissions limited to `cluckin-bell/*` repositories only
- **Trust Policy**: Constrained to GitHub OIDC with `aud=sts.amazonaws.com` and `sub=repo:oscarmartinez0880/cluckin-bell-app:*`

#### gha-eks-deploy  
- **Purpose**: Allows GitHub Actions from `oscarmartinez0880/cluckin-bell-app` to authenticate to EKS cluster
- **Permissions**: `eks:DescribeCluster` only
- **Trust Policy**: Constrained to GitHub OIDC with `aud=sts.amazonaws.com` and `sub=repo:oscarmartinez0880/cluckin-bell-app:*`
- **Note**: This role must be mapped into cluster RBAC via aws-auth in the EKS stack

## Security Features

- Trust policies are constrained to specific GitHub repositories
- ECR permissions are limited to cluckin-bell namespace only
- EKS permissions are minimal (describe cluster only)
- GitHub OIDC provider configured with proper security thumbprints

## Outputs

- `gha_ecr_push_role_arn`: ARN of the ECR push role
- `gha_eks_deploy_role_arn`: ARN of the EKS deploy role  
- `github_oidc_provider_arn`: ARN of the GitHub OIDC provider

## Usage

The output role ARNs should be used in the cluckin-bell-app repository's GitHub Actions workflows:

```yaml
- name: Configure AWS credentials for ECR
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.GHA_ECR_PUSH_ROLE_ARN }}
    aws-region: us-east-1

- name: Configure AWS credentials for EKS
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.GHA_EKS_DEPLOY_ROLE_ARN }}
    aws-region: us-east-1
```