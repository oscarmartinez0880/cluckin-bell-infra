#!/bin/bash

# ECR Workflow Test Runner
# This script helps run and monitor ECR workflow tests across all environments

set -euo pipefail

# Configuration
REPO_OWNER="oscarmartinez0880"
REPO_NAME="cluckin-bell-infra"
WORKFLOW_FILE="test-ecr-workflow.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
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
Usage: $0 [COMMAND] [OPTIONS]

Commands:
    run-tests       Run ECR workflow tests
    check-status    Check status of running workflows
    download-logs   Download logs and reports from recent runs
    help           Show this help message

Options for run-tests:
    --environment   Environment to test (dev|qa|prod|all) [default: all]
    --application   Application to test (cluckin-bell-app|wingman-api|all) [default: all]
    --dry-run      Run in dry run mode (true|false) [default: true]
    --wait         Wait for completion and show results

Options for download-logs:
    --run-id       Specific workflow run ID to download logs for
    --limit        Number of recent runs to check [default: 5]

Examples:
    # Run dry run tests for all environments and applications
    $0 run-tests

    # Run live tests for dev environment only
    $0 run-tests --environment dev --dry-run false --wait

    # Check status of recent workflows
    $0 check-status

    # Download logs from a specific run
    $0 download-logs --run-id 1234567890

EOF
}

check_requirements() {
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is required but not installed"
        log_info "Install it from: https://cli.github.com/"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI"
        log_info "Run 'gh auth login' to authenticate"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed"
        log_info "Install it from: https://stedolan.github.io/jq/"
        exit 1
    fi
}

run_workflow_tests() {
    local environment="${1:-all}"
    local application="${2:-all}"
    local dry_run="${3:-true}"
    local wait_for_completion="${4:-false}"

    log_info "Running ECR workflow tests..."
    log_info "  Environment: $environment"
    log_info "  Application: $application"
    log_info "  Dry Run: $dry_run"

    # Trigger the workflow
    local workflow_run_url
    workflow_run_url=$(gh workflow run "$WORKFLOW_FILE" \
        --repo "$REPO_OWNER/$REPO_NAME" \
        --field environment="$environment" \
        --field application="$application" \
        --field dry_run="$dry_run" \
        --json url --jq '.url' 2>/dev/null || echo "")

    if [[ -z "$workflow_run_url" ]]; then
        log_warning "Could not get workflow run URL, checking recent runs..."
        sleep 5
    fi

    # Get the most recent workflow run
    local run_id
    run_id=$(gh run list \
        --repo "$REPO_OWNER/$REPO_NAME" \
        --workflow "$WORKFLOW_FILE" \
        --limit 1 \
        --json databaseId \
        --jq '.[0].databaseId')

    if [[ -z "$run_id" ]]; then
        log_error "Could not find workflow run"
        exit 1
    fi

    log_success "Workflow triggered successfully!"
    log_info "Run ID: $run_id"
    log_info "View at: https://github.com/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id"

    if [[ "$wait_for_completion" == "true" ]]; then
        log_info "Waiting for workflow to complete..."
        
        while true; do
            local status conclusion
            status=$(gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --json status --jq '.status')
            conclusion=$(gh run view "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --json conclusion --jq '.conclusion')
            
            if [[ "$status" == "completed" ]]; then
                if [[ "$conclusion" == "success" ]]; then
                    log_success "Workflow completed successfully!"
                elif [[ "$conclusion" == "failure" ]]; then
                    log_error "Workflow failed"
                else
                    log_warning "Workflow completed with status: $conclusion"
                fi
                break
            else
                log_info "Workflow status: $status"
                sleep 30
            fi
        done

        # Download artifacts
        download_workflow_artifacts "$run_id"
    fi

    echo "$run_id"
}

check_workflow_status() {
    log_info "Checking recent ECR workflow runs..."

    gh run list \
        --repo "$REPO_OWNER/$REPO_NAME" \
        --workflow "$WORKFLOW_FILE" \
        --limit 10 \
        --json databaseId,status,conclusion,createdAt,headBranch,event \
        --template '{{range .}}{{tablerow (.databaseId | toString) .status .conclusion .createdAt .headBranch .event}}{{end}}'
}

download_workflow_artifacts() {
    local run_id="${1:-}"
    local limit="${2:-5}"

    if [[ -z "$run_id" ]]; then
        log_info "Finding recent workflow runs..."
        run_id=$(gh run list \
            --repo "$REPO_OWNER/$REPO_NAME" \
            --workflow "$WORKFLOW_FILE" \
            --limit "$limit" \
            --json databaseId,status \
            --jq '.[] | select(.status == "completed") | .databaseId' | head -1)
        
        if [[ -z "$run_id" ]]; then
            log_error "No completed workflow runs found"
            exit 1
        fi
    fi

    log_info "Downloading artifacts from run $run_id..."

    # Create download directory
    local download_dir="ecr-test-results-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$download_dir"

    # Download artifacts
    if gh run download "$run_id" --repo "$REPO_OWNER/$REPO_NAME" --dir "$download_dir"; then
        log_success "Artifacts downloaded to: $download_dir"
        
        # List downloaded files
        log_info "Downloaded files:"
        find "$download_dir" -type f -name "*.md" | while read -r file; do
            echo "  - $(basename "$file")"
        done

        # Show summary if available
        local summary_file
        summary_file=$(find "$download_dir" -name "*summary*.md" | head -1)
        if [[ -n "$summary_file" && -f "$summary_file" ]]; then
            log_info "Test Summary:"
            echo "----------------------------------------"
            cat "$summary_file"
            echo "----------------------------------------"
        fi
    else
        log_error "Failed to download artifacts"
        exit 1
    fi
}

generate_test_report() {
    local results_dir="${1:-./ecr-test-results-*}"
    
    log_info "Generating comprehensive test report..."
    
    local report_file="ecr-test-comprehensive-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# ECR Workflow Test Comprehensive Report

**Generated**: $(date -u)  
**Repository**: $REPO_OWNER/$REPO_NAME

## Overview

This report consolidates results from ECR workflow tests across all environments and applications.

## Test Environments

| Environment | Account ID | ECR Base URL |
|-------------|------------|--------------|
| dev | 264765154707 | 264765154707.dkr.ecr.us-east-1.amazonaws.com |
| qa | 264765154707 | 264765154707.dkr.ecr.us-east-1.amazonaws.com |
| prod | 346746763840 | 346746763840.dkr.ecr.us-east-1.amazonaws.com |

## Applications Tested

- **cluckin-bell-app**: Main web application container
- **wingman-api**: Backend API service container

## Test Results

EOF

    # Append individual test reports if available
    for results_dir in ./ecr-test-results-*; do
        if [[ -d "$results_dir" ]]; then
            log_info "Processing results from: $results_dir"
            
            find "$results_dir" -name "*.md" -type f | while read -r file; do
                echo "### $(basename "$file" .md)" >> "$report_file"
                echo "" >> "$report_file"
                cat "$file" >> "$report_file"
                echo "" >> "$report_file"
                echo "---" >> "$report_file"
                echo "" >> "$report_file"
            done
        fi
    done

    cat >> "$report_file" << EOF

## Troubleshooting

### Common Issues

1. **ECR Authentication Failed**
   - Verify GitHub OIDC roles are configured correctly
   - Check that the repository has access to the environment secrets

2. **ECR Repository Not Found**
   - Ensure ECR repositories are created via Terraform
   - Verify account IDs match the expected values

3. **Image Push Failed**
   - Check ECR repository policies
   - Verify IAM role permissions for ECR push operations

### Next Steps

1. **For Successful Tests**: Proceed with application deployment workflows
2. **For Failed Tests**: Review logs and check infrastructure configuration
3. **For Production**: Ensure all tests pass in dev/qa before running prod tests

## Command Reference

\`\`\`bash
# Run tests for specific environment
./scripts/run-ecr-tests.sh run-tests --environment dev --dry-run false

# Check workflow status
./scripts/run-ecr-tests.sh check-status

# Download latest results
./scripts/run-ecr-tests.sh download-logs
\`\`\`

EOF

    log_success "Comprehensive report generated: $report_file"
    
    if command -v open &> /dev/null; then
        open "$report_file" 2>/dev/null || true
    fi
}

main() {
    local command="${1:-help}"
    shift || true

    check_requirements

    case "$command" in
        run-tests)
            local environment="all"
            local application="all"
            local dry_run="true"
            local wait_for_completion="false"

            while [[ $# -gt 0 ]]; do
                case $1 in
                    --environment)
                        environment="$2"
                        shift 2
                        ;;
                    --application)
                        application="$2"
                        shift 2
                        ;;
                    --dry-run)
                        dry_run="$2"
                        shift 2
                        ;;
                    --wait)
                        wait_for_completion="true"
                        shift
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done

            run_workflow_tests "$environment" "$application" "$dry_run" "$wait_for_completion"
            ;;
        check-status)
            check_workflow_status
            ;;
        download-logs)
            local run_id=""
            local limit="5"

            while [[ $# -gt 0 ]]; do
                case $1 in
                    --run-id)
                        run_id="$2"
                        shift 2
                        ;;
                    --limit)
                        limit="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done

            download_workflow_artifacts "$run_id" "$limit"
            ;;
        generate-report)
            generate_test_report
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi