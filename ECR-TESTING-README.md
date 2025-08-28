# Issue #35: ECR Workflow Testing Implementation

This document provides a complete implementation for running and monitoring ECR workflow_dispatch tests across all environments.

## Quick Start

### 1. Test ECR Infrastructure (Dry Run)
```bash
make test-ecr-dry
```

### 2. Test Specific Environment
```bash
make test-ecr-dev    # Test dev environment
make test-ecr-qa     # Test qa environment
make test-ecr-prod   # Test prod environment
```

### 3. Test All Environments
```bash
make test-ecr-all
```

### 4. Check Test Status
```bash
make test-ecr-status
```

### 5. Collect Results and Generate Reports
```bash
make test-ecr-collect
```

## Files Created

| File | Purpose |
|------|---------|
| `.github/workflows/test-ecr-workflow.yml` | Main workflow for ECR testing |
| `scripts/run-ecr-tests.sh` | Test runner and monitoring script |
| `scripts/collect-ecr-results.sh` | Results collection and reporting |
| `docs/ecr-testing.md` | Complete testing documentation |
| `Makefile` | Added ECR testing targets |

## Environment Configuration

| Environment | Account | ECR Repository Base |
|-------------|---------|-------------------|
| dev | 264765154707 | `264765154707.dkr.ecr.us-east-1.amazonaws.com` |
| qa | 264765154707 | `264765154707.dkr.ecr.us-east-1.amazonaws.com` |
| prod | 346746763840 | `346746763840.dkr.ecr.us-east-1.amazonaws.com` |

## Expected Test Results

The workflow will test:
- ✅ ECR authentication using GitHub OIDC
- ✅ ECR repository access for both applications
- ✅ Container image building and tagging
- ✅ Image pushing to correct ECR repositories
- ✅ Proper environment-specific tagging

## Applications Tested

1. **cluckin-bell-app**: Main web application
2. **wingman-api**: Backend API service

## Image Tagging Strategy

- **dev**: Images tagged with `dev` and `sha-{git-sha}`
- **qa**: Images tagged with `qa` and `sha-{git-sha}`
- **prod**: Images tagged with `prod`, `latest`, and `sha-{git-sha}`

## Manual Workflow Execution

If you prefer to run workflows manually:

```bash
# Dry run test (safe)
gh workflow run test-ecr-workflow.yml \
  --repo oscarmartinez0880/cluckin-bell-infra \
  --field environment=all \
  --field application=all \
  --field dry_run=true

# Live test for dev environment
gh workflow run test-ecr-workflow.yml \
  --repo oscarmartinez0880/cluckin-bell-infra \
  --field environment=dev \
  --field application=all \
  --field dry_run=false
```

## Monitoring and Results

1. **View workflow runs**: https://github.com/oscarmartinez0880/cluckin-bell-infra/actions/workflows/test-ecr-workflow.yml
2. **Download test reports**: Workflow artifacts contain detailed reports
3. **Monitor via CLI**: `make test-ecr-status`

## Troubleshooting

### Common Issues

1. **Authentication Failed**: Check GitHub OIDC configuration
2. **Repository Not Found**: Ensure ECR repositories are created via Terraform
3. **Permission Denied**: Verify IAM role permissions

### Debug Commands

```bash
# Check workflow status
gh run list --workflow test-ecr-workflow.yml --repo oscarmartinez0880/cluckin-bell-infra

# View specific run
gh run view <RUN_ID> --repo oscarmartinez0880/cluckin-bell-infra

# Download logs
gh run download <RUN_ID> --repo oscarmartinez0880/cluckin-bell-infra
```

## Next Steps After Testing

1. ✅ Verify all tests pass in dry-run mode
2. ✅ Run live tests for each environment
3. ✅ Collect screenshots from AWS Console (ECR repositories)
4. ✅ Document any failures and resolution steps
5. ✅ Validate image tagging matches expected strategy

## Security Notes

- Uses GitHub OIDC (no long-lived AWS credentials)
- Environment-specific IAM roles with minimal permissions
- Dry-run mode available for safe testing
- Production tests should only run after dev/qa validation

## Support

For detailed documentation, see:
- [Complete ECR Testing Guide](./docs/ecr-testing.md)
- [Script Usage](./scripts/run-ecr-tests.sh help)
- [GitHub Actions Workflow](./github/workflows/test-ecr-workflow.yml)

## Issue Resolution

This implementation addresses all requirements from Issue #35:

- ✅ Workflow_dispatch capability for ECR testing
- ✅ Support for all environments (dev, qa, prod)
- ✅ Testing both applications (cluckin-bell-app, wingman-api)
- ✅ Log collection and result reporting
- ✅ Documentation for verification and screenshots
- ✅ Automated monitoring and troubleshooting tools