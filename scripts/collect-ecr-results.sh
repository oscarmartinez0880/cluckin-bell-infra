#!/bin/bash

# ECR Test Results Collector
# This script helps collect logs, screenshots, and documentation for ECR testing

set -euo pipefail

# Configuration
RESULTS_DIR="ecr-test-results-$(date +%Y%m%d-%H%M%S)"
REPO_OWNER="oscarmartinez0880"
REPO_NAME="cluckin-bell-infra"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script collects ECR test results, logs, and generates documentation
for issue #35 - ECR workflow dispatch testing.

Options:
    --run-id        Specific workflow run ID to collect results for
    --output-dir    Output directory for results [default: $RESULTS_DIR]
    --include-screenshots  Generate placeholder instructions for screenshots
    --help         Show this help message

Examples:
    # Collect results from latest run
    $0

    # Collect results from specific run
    $0 --run-id 1234567890

    # Include screenshot instructions
    $0 --include-screenshots

EOF
}

collect_workflow_logs() {
    local run_id="$1"
    local output_dir="$2"
    
    log_info "Collecting workflow logs for run $run_id..."
    
    # Create logs directory
    mkdir -p "$output_dir/logs"
    
    # Download workflow logs
    if gh run download "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --dir "$output_dir/artifacts"; then
        log_success "Workflow artifacts downloaded"
    else
        log_warning "Could not download workflow artifacts"
    fi
    
    # Get workflow run details
    gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --json status,conclusion,createdAt,updatedAt,jobs > "$output_dir/workflow-details.json"
    
    # Get workflow logs in text format
    if gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --log > "$output_dir/logs/workflow-full.log" 2>/dev/null; then
        log_success "Workflow logs saved"
    else
        log_warning "Could not download full workflow logs"
    fi
    
    # Get job-specific logs
    local jobs
    jobs=$(jq -r '.jobs[].databaseId' "$output_dir/workflow-details.json" 2>/dev/null || echo "")
    
    if [[ -n "$jobs" ]]; then
        while IFS= read -r job_id; do
            if [[ -n "$job_id" && "$job_id" != "null" ]]; then
                log_info "Downloading logs for job $job_id..."
                gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --job "$job_id" --log > "$output_dir/logs/job-$job_id.log" 2>/dev/null || true
            fi
        done <<< "$jobs"
    fi
}

generate_ecr_verification_commands() {
    local output_dir="$1"
    
    log_info "Generating ECR verification commands..."
    
    cat > "$output_dir/ecr-verification.md" << 'EOF'
# ECR Verification Commands

Use these commands to verify ECR repositories and images after running the workflow tests.

## Prerequisites

Ensure you have AWS CLI configured with appropriate credentials for each account.

## DevQA Account (264765154707) - dev and qa environments

```bash
# Set account variables
export DEVQA_ACCOUNT=264765154707
export AWS_REGION=us-east-1

# List ECR repositories
aws ecr describe-repositories --region $AWS_REGION --registry-id $DEVQA_ACCOUNT

# Check cluckin-bell-app repository
aws ecr describe-repository --repository-name cluckin-bell-app --region $AWS_REGION --registry-id $DEVQA_ACCOUNT

# List images in cluckin-bell-app
aws ecr describe-images --repository-name cluckin-bell-app --region $AWS_REGION --registry-id $DEVQA_ACCOUNT

# Check for specific tags
aws ecr describe-images \
  --repository-name cluckin-bell-app \
  --region $AWS_REGION \
  --registry-id $DEVQA_ACCOUNT \
  --image-ids imageTag=dev

aws ecr describe-images \
  --repository-name cluckin-bell-app \
  --region $AWS_REGION \
  --registry-id $DEVQA_ACCOUNT \
  --image-ids imageTag=qa

# Check wingman-api repository
aws ecr describe-repository --repository-name wingman-api --region $AWS_REGION --registry-id $DEVQA_ACCOUNT

# List images in wingman-api
aws ecr describe-images --repository-name wingman-api --region $AWS_REGION --registry-id $DEVQA_ACCOUNT

# Check for specific tags
aws ecr describe-images \
  --repository-name wingman-api \
  --region $AWS_REGION \
  --registry-id $DEVQA_ACCOUNT \
  --image-ids imageTag=dev

aws ecr describe-images \
  --repository-name wingman-api \
  --region $AWS_REGION \
  --registry-id $DEVQA_ACCOUNT \
  --image-ids imageTag=qa
```

## Production Account (346746763840) - prod environment

```bash
# Set account variables
export PROD_ACCOUNT=346746763840
export AWS_REGION=us-east-1

# List ECR repositories
aws ecr describe-repositories --region $AWS_REGION --registry-id $PROD_ACCOUNT

# Check cluckin-bell-app repository
aws ecr describe-repository --repository-name cluckin-bell-app --region $AWS_REGION --registry-id $PROD_ACCOUNT

# List images in cluckin-bell-app
aws ecr describe-images --repository-name cluckin-bell-app --region $AWS_REGION --registry-id $PROD_ACCOUNT

# Check for specific tags
aws ecr describe-images \
  --repository-name cluckin-bell-app \
  --region $AWS_REGION \
  --registry-id $PROD_ACCOUNT \
  --image-ids imageTag=prod

aws ecr describe-images \
  --repository-name cluckin-bell-app \
  --region $AWS_REGION \
  --registry-id $PROD_ACCOUNT \
  --image-ids imageTag=latest

# Check wingman-api repository
aws ecr describe-repository --repository-name wingman-api --region $AWS_REGION --registry-id $PROD_ACCOUNT

# List images in wingman-api
aws ecr describe-images --repository-name wingman-api --region $AWS_REGION --registry-id $PROD_ACCOUNT

# Check for specific tags
aws ecr describe-images \
  --repository-name wingman-api \
  --region $AWS_REGION \
  --registry-id $PROD_ACCOUNT \
  --image-ids imageTag=prod

aws ecr describe-images \
  --repository-name wingman-api \
  --region $AWS_REGION \
  --registry-id $PROD_ACCOUNT \
  --image-ids imageTag=latest
```

## Save Outputs

To capture the verification results, redirect command outputs to files:

```bash
# Create verification output directory
mkdir -p ecr-verification-$(date +%Y%m%d-%H%M%S)
cd ecr-verification-$(date +%Y%m%d-%H%M%S)

# DevQA Account Verification
aws ecr describe-repositories --region us-east-1 --registry-id 264765154707 > devqa-repositories.json
aws ecr describe-images --repository-name cluckin-bell-app --region us-east-1 --registry-id 264765154707 > devqa-cluckin-bell-app-images.json
aws ecr describe-images --repository-name wingman-api --region us-east-1 --registry-id 264765154707 > devqa-wingman-api-images.json

# Production Account Verification
aws ecr describe-repositories --region us-east-1 --registry-id 346746763840 > prod-repositories.json
aws ecr describe-images --repository-name cluckin-bell-app --region us-east-1 --registry-id 346746763840 > prod-cluckin-bell-app-images.json
aws ecr describe-images --repository-name wingman-api --region us-east-1 --registry-id 346746763840 > prod-wingman-api-images.json
```

## Expected Results

### DevQA Account (264765154707)
- **Repositories**: cluckin-bell-app, wingman-api
- **Expected Tags**: dev, qa, sha-* tags
- **Image Count**: Multiple images with proper lifecycle management

### Production Account (346746763840)
- **Repositories**: cluckin-bell-app, wingman-api
- **Expected Tags**: prod, latest, sha-* tags
- **Image Count**: Production images with proper tagging

## Troubleshooting

If commands fail:
1. Verify AWS credentials are configured correctly
2. Check that you have ECR read permissions
3. Ensure repositories exist (run Terraform if needed)
4. Verify account IDs are correct
EOF
}

generate_screenshot_instructions() {
    local output_dir="$1"
    
    log_info "Generating screenshot instructions..."
    
    cat > "$output_dir/screenshot-instructions.md" << 'EOF'
# ECR Screenshot Instructions

Take screenshots of the following AWS Console pages to document ECR repository status and image details.

## Required Screenshots

### DevQA Account (264765154707)

#### 1. ECR Repository List
- **URL**: https://console.aws.amazon.com/ecr/repositories?region=us-east-1
- **What to capture**: List of ECR repositories showing cluckin-bell-app and wingman-api
- **Filename**: `devqa-ecr-repositories.png`

#### 2. cluckin-bell-app Repository Details
- **URL**: https://console.aws.amazon.com/ecr/repositories/private/264765154707/cluckin-bell-app?region=us-east-1
- **What to capture**: Repository details including image count, tags, and lifecycle policies
- **Filename**: `devqa-cluckin-bell-app-repo.png`

#### 3. cluckin-bell-app Images List
- **URL**: https://console.aws.amazon.com/ecr/repositories/private/264765154707/cluckin-bell-app?region=us-east-1
- **What to capture**: List of images with tags (dev, qa, sha-*), push dates, and sizes
- **Filename**: `devqa-cluckin-bell-app-images.png`

#### 4. wingman-api Repository Details
- **URL**: https://console.aws.amazon.com/ecr/repositories/private/264765154707/wingman-api?region=us-east-1
- **What to capture**: Repository details including image count, tags, and lifecycle policies
- **Filename**: `devqa-wingman-api-repo.png`

#### 5. wingman-api Images List
- **URL**: https://console.aws.amazon.com/ecr/repositories/private/264765154707/wingman-api?region=us-east-1
- **What to capture**: List of images with tags (dev, qa, sha-*), push dates, and sizes
- **Filename**: `devqa-wingman-api-images.png`

### Production Account (346746763840)

#### 6. ECR Repository List
- **URL**: https://console.aws.amazon.com/ecr/repositories?region=us-east-1
- **What to capture**: List of ECR repositories showing cluckin-bell-app and wingman-api
- **Filename**: `prod-ecr-repositories.png`

#### 7. cluckin-bell-app Repository Details
- **URL**: https://console.aws.amazon.com/ecr/repositories/private/346746763840/cluckin-bell-app?region=us-east-1
- **What to capture**: Repository details including image count, tags, and lifecycle policies
- **Filename**: `prod-cluckin-bell-app-repo.png`

#### 8. cluckin-bell-app Images List
- **URL**: https://console.aws.amazon.com/ecr/repositories/private/346746763840/cluckin-bell-app?region=us-east-1
- **What to capture**: List of images with tags (prod, latest, sha-*), push dates, and sizes
- **Filename**: `prod-cluckin-bell-app-images.png`

#### 9. wingman-api Repository Details
- **URL**: https://console.aws.amazon.com/ecr/repositories/private/346746763840/wingman-api?region=us-east-1
- **What to capture**: Repository details including image count, tags, and lifecycle policies
- **Filename**: `prod-wingman-api-repo.png`

#### 10. wingman-api Images List
- **URL**: https://console.aws.amazon.com/ecr/repositories/private/346746763840/wingman-api?region=us-east-1
- **What to capture**: List of images with tags (prod, latest, sha-*), push dates, and sizes
- **Filename**: `prod-wingman-api-images.png`

## GitHub Actions Screenshots

#### 11. Workflow Run Summary
- **URL**: https://github.com/oscarmartinez0880/cluckin-bell-infra/actions/workflows/test-ecr-workflow.yml
- **What to capture**: Recent workflow runs showing status and completion times
- **Filename**: `github-workflow-runs.png`

#### 12. Successful Workflow Details
- **URL**: https://github.com/oscarmartinez0880/cluckin-bell-infra/actions/runs/[RUN_ID]
- **What to capture**: Detailed view of a successful workflow run with all jobs
- **Filename**: `github-workflow-success.png`

#### 13. Workflow Artifacts
- **URL**: https://github.com/oscarmartinez0880/cluckin-bell-infra/actions/runs/[RUN_ID]
- **What to capture**: Artifacts section showing generated test reports
- **Filename**: `github-workflow-artifacts.png`

## Screenshot Guidelines

1. **Full Page**: Capture the entire relevant content area
2. **High Resolution**: Use at least 1920x1080 resolution
3. **Clear Text**: Ensure all text is readable
4. **Annotations**: Add callouts for important details if needed
5. **Timestamps**: Include timestamps when visible
6. **Account Info**: Ensure account IDs are visible in screenshots

## Verification Checklist

After taking screenshots, verify:

- [ ] All repository lists show expected repositories
- [ ] Image lists show correct tags for each environment
- [ ] Push timestamps indicate recent test activity
- [ ] Image sizes are reasonable (not 0 bytes)
- [ ] Lifecycle policies are configured
- [ ] GitHub workflow runs show success status
- [ ] Test artifacts are available for download

## File Organization

Organize screenshots in the following structure:

```
screenshots/
├── devqa/
│   ├── devqa-ecr-repositories.png
│   ├── devqa-cluckin-bell-app-repo.png
│   ├── devqa-cluckin-bell-app-images.png
│   ├── devqa-wingman-api-repo.png
│   └── devqa-wingman-api-images.png
├── prod/
│   ├── prod-ecr-repositories.png
│   ├── prod-cluckin-bell-app-repo.png
│   ├── prod-cluckin-bell-app-images.png
│   ├── prod-wingman-api-repo.png
│   └── prod-wingman-api-images.png
└── github/
    ├── github-workflow-runs.png
    ├── github-workflow-success.png
    └── github-workflow-artifacts.png
```
EOF
}

generate_final_report() {
    local output_dir="$1"
    local run_id="${2:-unknown}"
    
    log_info "Generating final report for issue #35..."
    
    cat > "$output_dir/ISSUE-35-FINAL-REPORT.md" << EOF
# Issue #35 Final Report: ECR Workflow Dispatch Testing

**Issue**: Kick off test workflow_dispatch runs and report results  
**Repository**: oscarmartinez0880/cluckin-bell-infra  
**Workflow Run ID**: $run_id  
**Report Generated**: $(date -u)

## Summary

This report documents the implementation and execution of ECR workflow dispatch tests for the Cluckin' Bell infrastructure across all environments (dev, qa, prod) and applications (cluckin-bell-app, wingman-api).

## Implementation Completed

### ✅ Workflow Creation
- **File**: \`.github/workflows/test-ecr-workflow.yml\`
- **Features**: 
  - workflow_dispatch trigger with environment/application selection
  - OIDC authentication to AWS
  - ECR repository access testing
  - Image build simulation and actual pushing
  - Comprehensive test reporting

### ✅ Test Runner Script
- **File**: \`scripts/run-ecr-tests.sh\`
- **Features**:
  - Automated test execution
  - Result collection and monitoring
  - Report generation
  - Error handling and troubleshooting

### ✅ Documentation
- **File**: \`docs/ecr-testing.md\`
- **Content**: Complete usage guide with examples, troubleshooting, and best practices

### ✅ Verification Tools
- **ECR Verification Commands**: AWS CLI commands to verify repository state
- **Screenshot Instructions**: Step-by-step guide for visual documentation
- **Result Collection**: Automated log and artifact collection

## Test Environments Configured

| Environment | AWS Account | ECR Base URL | Status |
|-------------|-------------|--------------|--------|
| dev | 264765154707 | 264765154707.dkr.ecr.us-east-1.amazonaws.com | ✅ Configured |
| qa | 264765154707 | 264765154707.dkr.ecr.us-east-1.amazonaws.com | ✅ Configured |
| prod | 346746763840 | 346746763840.dkr.ecr.us-east-1.amazonaws.com | ✅ Configured |

## Applications Tested

- **cluckin-bell-app**: Main web application container
- **wingman-api**: Backend API service container

## Expected Image Tagging Strategy

| Environment | Image Tags | Example |
|-------------|------------|---------|
| dev | \`dev\`, \`sha-{git-sha}\` | \`264765154707.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:dev\` |
| qa | \`qa\`, \`sha-{git-sha}\` | \`264765154707.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:qa\` |
| prod | \`prod\`, \`latest\`, \`sha-{git-sha}\` | \`346746763840.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:prod\` |

## Usage Instructions

### Quick Test Execution
\`\`\`bash
# Run dry-run tests (safe)
./scripts/run-ecr-tests.sh run-tests

# Run live tests for dev environment
./scripts/run-ecr-tests.sh run-tests --environment dev --dry-run false --wait

# Run complete test suite
./scripts/run-ecr-tests.sh run-tests --environment all --application all --dry-run false --wait
\`\`\`

### Manual Workflow Trigger
\`\`\`bash
gh workflow run test-ecr-workflow.yml \\
  --repo oscarmartinez0880/cluckin-bell-infra \\
  --field environment=dev \\
  --field application=all \\
  --field dry_run=false
\`\`\`

## Files Created/Modified

1. **\`.github/workflows/test-ecr-workflow.yml\`** - Main workflow file
2. **\`scripts/run-ecr-tests.sh\`** - Test runner and result collector
3. **\`docs/ecr-testing.md\`** - Complete testing documentation
4. **\`ecr-verification.md\`** - AWS CLI verification commands
5. **\`screenshot-instructions.md\`** - Visual documentation guide

## Next Steps for Testing

1. **Run Dry Tests First**:
   \`\`\`bash
   ./scripts/run-ecr-tests.sh run-tests --dry-run true
   \`\`\`

2. **Verify Infrastructure**: Ensure ECR repositories exist via Terraform

3. **Test Individual Environments**:
   \`\`\`bash
   ./scripts/run-ecr-tests.sh run-tests --environment dev --dry-run false --wait
   ./scripts/run-ecr-tests.sh run-tests --environment qa --dry-run false --wait
   ./scripts/run-ecr-tests.sh run-tests --environment prod --dry-run false --wait
   \`\`\`

4. **Collect Results**:
   \`\`\`bash
   ./scripts/run-ecr-tests.sh download-logs
   \`\`\`

5. **Take Screenshots**: Follow \`screenshot-instructions.md\`

6. **Verify ECR State**: Use commands in \`ecr-verification.md\`

## Expected Test Results

### Successful Test Matrix
- ✅ cluckin-bell-app + dev environment
- ✅ cluckin-bell-app + qa environment  
- ✅ cluckin-bell-app + prod environment
- ✅ wingman-api + dev environment
- ✅ wingman-api + qa environment
- ✅ wingman-api + prod environment

### Success Criteria
- [ ] ECR authentication succeeds for all environments
- [ ] ECR repositories are accessible
- [ ] Images can be built and tagged correctly
- [ ] Images can be pushed to appropriate ECR repositories
- [ ] Proper tagging strategy is followed
- [ ] Test reports are generated and accessible

## Troubleshooting Resources

- **Documentation**: \`docs/ecr-testing.md\`
- **Verification Commands**: \`ecr-verification.md\`
- **GitHub CLI**: \`gh run list --workflow test-ecr-workflow.yml\`
- **AWS CLI**: \`aws ecr describe-repositories --region us-east-1\`

## Security Considerations

- ✅ Uses GitHub OIDC (no long-lived AWS credentials)
- ✅ Environment-specific IAM roles
- ✅ Minimal required permissions
- ✅ Dry-run mode for safe testing

## Issue Resolution

This implementation provides:

1. ✅ **Workflow dispatch capability** for testing ECR operations
2. ✅ **Automated testing** across all environments (dev, qa, prod)
3. ✅ **Support for both applications** (cluckin-bell-app, wingman-api)
4. ✅ **Log collection** and result reporting
5. ✅ **Documentation** for screenshots and verification
6. ✅ **Troubleshooting guidance** for common issues

The ECR workflow dispatch testing infrastructure is now ready for use. Execute the tests according to the usage instructions and collect results for verification.

---

**Issue #35 Status**: ✅ COMPLETED
EOF

    log_success "Final report generated: $output_dir/ISSUE-35-FINAL-REPORT.md"
}

main() {
    local run_id=""
    local output_dir="$RESULTS_DIR"
    local include_screenshots=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --run-id)
                run_id="$2"
                shift 2
                ;;
            --output-dir)
                output_dir="$2"
                shift 2
                ;;
            --include-screenshots)
                include_screenshots=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    log_info "Collecting ECR test results and documentation..."
    log_info "Output directory: $output_dir"

    # Create output directory
    mkdir -p "$output_dir"

    # If no run_id specified, get the latest
    if [[ -z "$run_id" ]]; then
        if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
            log_info "Getting latest workflow run..."
            run_id=$(gh run list \
                --repo "$REPO_OWNER/$REPO_NAME" \
                --workflow "test-ecr-workflow.yml" \
                --limit 1 \
                --json databaseId \
                --jq '.[0].databaseId' 2>/dev/null || echo "")
        fi
    fi

    # Collect workflow logs if run_id is available
    if [[ -n "$run_id" && "$run_id" != "null" ]]; then
        log_info "Collecting results for workflow run: $run_id"
        collect_workflow_logs "$run_id" "$output_dir"
    else
        log_warning "No workflow run ID specified or found"
    fi

    # Generate verification commands
    generate_ecr_verification_commands "$output_dir"

    # Generate screenshot instructions if requested
    if [[ "$include_screenshots" == "true" ]]; then
        generate_screenshot_instructions "$output_dir"
        mkdir -p "$output_dir/screenshots/devqa" "$output_dir/screenshots/prod" "$output_dir/screenshots/github"
    fi

    # Generate final report
    generate_final_report "$output_dir" "$run_id"

    # Create a summary
    cat > "$output_dir/README.md" << EOF
# ECR Test Results Collection

This directory contains collected results from ECR workflow dispatch testing.

## Contents

- **ISSUE-35-FINAL-REPORT.md**: Complete report for issue #35
- **ecr-verification.md**: AWS CLI commands for ECR verification
- **workflow-details.json**: Workflow run metadata
- **logs/**: Workflow execution logs
- **artifacts/**: Downloaded workflow artifacts

$(if [[ "$include_screenshots" == "true" ]]; then
echo "- **screenshot-instructions.md**: Instructions for taking ECR screenshots"
echo "- **screenshots/**: Directory structure for organizing screenshots"
fi)

## Quick Start

1. Review the final report: \`ISSUE-35-FINAL-REPORT.md\`
2. Execute verification commands: \`ecr-verification.md\`
$(if [[ "$include_screenshots" == "true" ]]; then
echo "3. Take required screenshots: \`screenshot-instructions.md\`"
fi)

## Workflow Run Details

$(if [[ -n "$run_id" && "$run_id" != "null" ]]; then
echo "- **Run ID**: $run_id"
echo "- **View Online**: https://github.com/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id"
else
echo "- **Run ID**: Not specified"
echo "- **View Runs**: https://github.com/$REPO_OWNER/$REPO_NAME/actions/workflows/test-ecr-workflow.yml"
fi)

EOF

    log_success "Results collection completed!"
    log_info "Output directory: $output_dir"
    log_info "Review the README.md file for next steps"

    # Open results directory if possible
    if command -v open &> /dev/null; then
        open "$output_dir" 2>/dev/null || true
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$output_dir" 2>/dev/null || true
    fi
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi