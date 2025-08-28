#!/bin/bash

# Validation script for Kubernetes deployment templates
# This script validates the templates can be rendered correctly

set -e

echo "🔍 Validating Kubernetes deployment templates..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "success") echo -e "${GREEN}✓${NC} $message" ;;
        "warning") echo -e "${YELLOW}⚠${NC} $message" ;;
        "error") echo -e "${RED}✗${NC} $message" ;;
        "info") echo -e "${YELLOW}ℹ${NC} $message" ;;
    esac
}

# Validate directory structure
print_status "info" "Checking template directory structure..."

required_dirs=(
    "templates/helm/cluckin-bell-app"
    "templates/helm/wingman-api"
    "templates/kustomize/cluckin-bell-app/base"
    "templates/kustomize/cluckin-bell-app/overlays/dev"
    "templates/kustomize/cluckin-bell-app/overlays/qa"
    "templates/kustomize/cluckin-bell-app/overlays/prod"
    "templates/kustomize/wingman-api/base"
    "templates/kustomize/wingman-api/overlays/dev"
    "templates/kustomize/wingman-api/overlays/qa"
    "templates/kustomize/wingman-api/overlays/prod"
)

for dir in "${required_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        print_status "success" "Found directory: $dir"
    else
        print_status "error" "Missing directory: $dir"
        exit 1
    fi
done

# Validate environment-specific configurations
print_status "info" "Validating environment-specific image configurations..."

# Check dev environment uses nonprod ECR
dev_image_repo="264765154707.dkr.ecr.us-east-1.amazonaws.com"
qa_image_repo="264765154707.dkr.ecr.us-east-1.amazonaws.com"
prod_image_repo="346746763840.dkr.ecr.us-east-1.amazonaws.com"

# Check Helm values files
for app in "cluckin-bell-app" "wingman-api"; do
    # Dev environment
    if grep -q "$dev_image_repo/$app" "templates/helm/$app/values.dev.yaml" && grep -q "tag.*dev" "templates/helm/$app/values.dev.yaml"; then
        print_status "success" "Helm $app dev values: correct ECR repository and tag"
    else
        print_status "error" "Helm $app dev values: incorrect ECR repository or tag"
    fi
    
    # QA environment
    if grep -q "$qa_image_repo/$app" "templates/helm/$app/values.qa.yaml" && grep -q "tag.*qa" "templates/helm/$app/values.qa.yaml"; then
        print_status "success" "Helm $app qa values: correct ECR repository and tag"
    else
        print_status "error" "Helm $app qa values: incorrect ECR repository or tag"
    fi
    
    # Prod environment
    if grep -q "$prod_image_repo/$app" "templates/helm/$app/values.prod.yaml" && grep -q "tag.*prod" "templates/helm/$app/values.prod.yaml"; then
        print_status "success" "Helm $app prod values: correct ECR repository and tag"
    else
        print_status "error" "Helm $app prod values: incorrect ECR repository or tag"
    fi
done

# Check Kustomize overlays
for app in "cluckin-bell-app" "wingman-api"; do
    # Dev environment
    if grep -q "newTag.*dev" "templates/kustomize/$app/overlays/dev/kustomization.yaml"; then
        print_status "success" "Kustomize $app dev overlay: correct image tag"
    else
        print_status "error" "Kustomize $app dev overlay: incorrect image tag"
    fi
    
    # QA environment
    if grep -q "newTag.*qa" "templates/kustomize/$app/overlays/qa/kustomization.yaml"; then
        print_status "success" "Kustomize $app qa overlay: correct image tag"
    else
        print_status "error" "Kustomize $app qa overlay: incorrect image tag"
    fi
    
    # Prod environment - should have newName AND newTag
    if grep -q "newName.*$prod_image_repo/$app" "templates/kustomize/$app/overlays/prod/kustomization.yaml" && grep -q "newTag.*prod" "templates/kustomize/$app/overlays/prod/kustomization.yaml"; then
        print_status "success" "Kustomize $app prod overlay: correct ECR repository and tag"
    else
        print_status "error" "Kustomize $app prod overlay: incorrect ECR repository or tag"
    fi
done

# Validate no :latest tags outside prod
print_status "info" "Checking for inappropriate :latest tag usage..."

latest_found=false
for file in $(find templates/ -name "*.yaml" -not -path "*/prod/*"); do
    if grep -q ":latest" "$file"; then
        print_status "error" "Found :latest tag in non-prod file: $file"
        latest_found=true
    fi
done

if ! $latest_found; then
    print_status "success" "No inappropriate :latest tags found"
fi

# Validate environment-specific domains
print_status "info" "Checking environment-specific domain configurations..."

# Dev domains
dev_domains_correct=true
if ! grep -r "dev\.cluckn-bell\.com" templates/helm/cluckin-bell-app/values.dev.yaml > /dev/null 2>&1; then
    print_status "error" "Missing dev.cluckn-bell.com in cluckin-bell-app dev values"
    dev_domains_correct=false
fi
if ! grep -r "api\.dev\.cluckn-bell\.com" templates/helm/wingman-api/values.dev.yaml > /dev/null 2>&1; then
    print_status "error" "Missing api.dev.cluckn-bell.com in wingman-api dev values"
    dev_domains_correct=false
fi

if $dev_domains_correct; then
    print_status "success" "Dev domains correctly configured"
fi

# QA domains
qa_domains_correct=true
if ! grep -r "qa\.cluckn-bell\.com" templates/helm/cluckin-bell-app/values.qa.yaml > /dev/null 2>&1; then
    print_status "error" "Missing qa.cluckn-bell.com in cluckin-bell-app qa values"
    qa_domains_correct=false
fi
if ! grep -r "api\.qa\.cluckn-bell\.com" templates/helm/wingman-api/values.qa.yaml > /dev/null 2>&1; then
    print_status "error" "Missing api.qa.cluckn-bell.com in wingman-api qa values"
    qa_domains_correct=false
fi

if $qa_domains_correct; then
    print_status "success" "QA domains correctly configured"
fi

# Prod domains  
prod_domains_correct=true
if ! grep -r "cluckn-bell\.com" templates/helm/cluckin-bell-app/values.prod.yaml > /dev/null 2>&1; then
    print_status "error" "Missing cluckn-bell.com in cluckin-bell-app prod values"
    prod_domains_correct=false
fi
if ! grep -r "api\.cluckn-bell\.com" templates/helm/wingman-api/values.prod.yaml > /dev/null 2>&1; then
    print_status "error" "Missing api.cluckn-bell.com in wingman-api prod values"
    prod_domains_correct=false
fi

if $prod_domains_correct; then
    print_status "success" "Prod domains correctly configured"
fi

# Validate HPA only in prod
print_status "info" "Checking HPA configuration..."

hpa_correct=true
for app in "cluckin-bell-app" "wingman-api"; do
    # Check HPA enabled in prod
    if grep -A1 "autoscaling:" "templates/helm/$app/values.prod.yaml" | grep -q "enabled.*true"; then
        print_status "success" "HPA enabled in $app prod values"
    else
        print_status "warning" "HPA not enabled in $app prod values"
    fi
    
    # Check HPA disabled by default
    if grep -A1 "autoscaling:" "templates/helm/$app/values.yaml" | grep -q "enabled.*false"; then
        print_status "success" "HPA correctly disabled by default in $app values"
    else
        print_status "warning" "HPA configuration may be incorrect in $app default values"
    fi
    
    # Check HPA resource exists in Kustomize prod overlay
    if [[ -f "templates/kustomize/$app/overlays/prod/hpa.yaml" ]]; then
        print_status "success" "HPA resource found in $app prod Kustomize overlay"
    else
        print_status "error" "HPA resource missing in $app prod Kustomize overlay"
        hpa_correct=false
    fi
done

print_status "info" "Validation complete!"

if $latest_found || ! $dev_domains_correct || ! $qa_domains_correct || ! $prod_domains_correct || ! $hpa_correct; then
    print_status "error" "Some validations failed"
    exit 1
else
    print_status "success" "All validations passed! Templates are ready for use."
fi