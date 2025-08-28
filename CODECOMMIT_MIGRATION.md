# CodeCommit Migration Summary

## Overview

Successfully migrated Argo CD infrastructure from GitHub App authentication to AWS CodeCommit as the GitOps source, eliminating the need for a GitHub App while preserving all existing functionality including cluckn-bell.com domain, private/internal Ingress for Argo CD with TLS, and staging privacy/Okta policy.

## Changes Implemented

### 1. AWS CodeCommit Repository

**New Resource:**
- `aws_codecommit_repository.cluckin_bell` - CodeCommit repository named "cluckin-bell" in us-east-1

### 2. IAM Resources (IRSA)

**New Resources:**
- `module.argocd_repo_server_irsa` - IRSA role for argocd-repo-server service account
- `aws_iam_policy.argocd_codecommit_access` - Read-only access policy for CodeCommit
- `aws_iam_role_policy_attachment.argocd_codecommit_access` - Policy attachment

**IAM Configuration:**
- **Trust Policy**: Bound to EKS OIDC provider for service account `cluckin-bell:argocd-repo-server`
- **Permissions**: Read-only CodeCommit access (`codecommit:GitPull`, `Get*`, `List*`, `BatchGet*`)
- **Resource Scope**: Limited to `arn:aws:codecommit:us-east-1:${account_id}:cluckin-bell`

### 3. Argo CD Configuration Updates

#### Main Infrastructure (k8s-controllers module)
- **Repository Configuration**: Added repository entry with CodeCommit URL `codecommit::us-east-1://cluckin-bell`
- **Service Account**: IRSA annotation for `argocd-repo-server`
- **Init Container**: Installs `git-remote-codecommit` via pip into `/custom-tools`
- **Environment Variables**: 
  - `AWS_REGION=us-east-1`
  - `PATH` includes `/custom-tools` for git-remote-codecommit access
- **Volumes**: Custom tools volume for git-remote-codecommit

#### Environment-Specific Stacks
- **Updated Applications**: All environment stacks (dev/qa/prod) now reference CodeCommit
- **Repository URLs**: Changed from GitHub HTTPS to CodeCommit format
- **IRSA Integration**: Each environment has its own IRSA role and policy

### 4. Removed GitHub Dependencies

**Removed Variables:**
- `github_app_id`
- `github_app_installation_id` 
- `github_app_private_key`

**Removed Resources:**
- GitHub App credential secrets
- GitHub-specific repository configurations

### 5. New Outputs

**Added Outputs:**
- `codecommit_repository_name`
- `codecommit_repository_arn`
- `codecommit_repository_clone_url_ssh`
- `codecommit_repository_clone_url_https`
- `argocd_repo_server_role_arn`

## Repository Structure

The migration affects two Argo CD deployments:

1. **Main Infrastructure** (`main.tf` + `k8s-controllers` module)
   - Used for infrastructure-level GitOps
   - Internal ALB with TLS termination
   - Environment-specific domains

2. **Environment-Specific Stacks** (`stacks/environments/*/main.tf` + `argocd` module)
   - Used for application-level GitOps
   - Dedicated per environment (dev/qa/prod)
   - LoadBalancer service with NLB

## Configuration Details

### Git Remote CodeCommit Installation

Both Argo CD deployments now include an init container that:

```yaml
initContainers:
  - name: install-git-remote-codecommit
    image: python:3.9-alpine
    command: ["/bin/sh", "-c"]
    args:
      - "pip install git-remote-codecommit && cp -r /usr/local/lib/python3.9/site-packages/git_remote_codecommit /custom-tools/ && cp /usr/local/bin/git-remote-codecommit /custom-tools/"
    volumeMounts:
      - name: custom-tools
        mountPath: /custom-tools
```

### Environment Variables

```yaml
env:
  - name: AWS_REGION
    value: us-east-1
  - name: PATH
    value: "/custom-tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
```

### Repository Configuration

Applications now reference:
- **URL Format**: `codecommit::us-east-1://cluckin-bell`
- **Paths**: Maintain existing structure (`k8s/dev`, `k8s/qa`, `k8s/prod`)

## Post-Migration Steps

### 1. Repository Setup

After applying the Terraform changes:

1. **Clone the new CodeCommit repository:**
   ```bash
   git clone codecommit::us-east-1://cluckin-bell
   ```

2. **Migrate existing k8s manifests** from the GitHub repository to CodeCommit:
   ```bash
   # Copy k8s/ directory structure from existing GitHub repo
   cp -r /path/to/github/repo/k8s/ ./cluckin-bell/
   cd cluckin-bell
   git add k8s/
   git commit -m "Initial migration from GitHub"
   git push
   ```

### 2. Validation

1. **Verify IRSA role permissions:**
   ```bash
   kubectl describe serviceaccount argocd-repo-server -n cluckin-bell
   ```

2. **Check Argo CD repository connectivity:**
   - Access Argo CD UI via internal ALB or port-forward
   - Verify repository appears in Settings > Repositories
   - Confirm applications can sync from CodeCommit

### 3. Cleanup

After successful migration and validation:
- Remove GitHub App from the GitHub organization
- Delete GitHub App credentials from any secret management systems
- Update documentation to reference CodeCommit instead of GitHub

## Security Improvements

1. **No Long-lived Credentials**: Uses IAM roles instead of GitHub App credentials
2. **Least Privilege**: IAM policy grants minimal required CodeCommit permissions
3. **Regional Scope**: All resources scoped to us-east-1
4. **Account Isolation**: IAM policies scope access to specific CodeCommit repository

## Preserved Functionality

✅ **Domain Configuration**: cluckn-bell.com domains maintained  
✅ **TLS Configuration**: cert-manager with Let's Encrypt still active  
✅ **Internal ALB**: Private Argo CD access preserved  
✅ **Environment Separation**: dev/qa/prod isolation maintained  
✅ **Application Structure**: Existing k8s/ directory structure compatible  
✅ **GitOps Workflows**: Sync policies and automation preserved  

## Terraform Validation

All configurations have been validated:
- ✅ Main infrastructure (`terraform validate` passed)
- ✅ Dev environment stack (`terraform validate` passed)  
- ✅ QA environment stack (`terraform validate` passed)
- ✅ Prod environment stack (`terraform validate` passed)