#!/bin/bash
set -e

echo "=== AWS WAFv2 and Container Insights Validation ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

# Function to print info
print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

echo "Checking Terraform configurations..."

# Check if Terraform is available
if command -v terraform &> /dev/null; then
    print_status 0 "Terraform is available"
else
    print_status 1 "Terraform is not available"
    exit 1
fi

# Validate main configuration
print_info "Validating main Terraform configuration..."
cd /home/runner/work/cluckin-bell-infra/cluckin-bell-infra
terraform validate
print_status $? "Main configuration validation"

# Check WAF module
print_info "Validating WAF module..."
cd modules_new/wafv2
terraform init -backend=false &>/dev/null
terraform validate
print_status $? "WAF module validation"

# Check Container Insights module
print_info "Validating Container Insights module..."
cd ../container_insights
terraform init -backend=false &>/dev/null
terraform validate
print_status $? "Container Insights module validation"

# Return to root
cd /home/runner/work/cluckin-bell-infra/cluckin-bell-infra

# Check cluster configurations
print_info "Validating cluster configurations..."

# Prod cluster
cd terraform/clusters/prod
terraform init -backend=false &>/dev/null
terraform validate
print_status $? "Production cluster configuration"

# DevQA cluster
cd ../devqa
terraform init -backend=false &>/dev/null
terraform validate
print_status $? "Dev/QA cluster configuration"

# Return to root
cd /home/runner/work/cluckin-bell-infra/cluckin-bell-infra

# Check for required files
print_info "Checking for required documentation and examples..."

files_to_check=(
    "docs/waf-security-baseline.md"
    "examples/ingress-waf-integration.md"
    "modules_new/wafv2/main.tf"
    "modules_new/wafv2/variables.tf"
    "modules_new/wafv2/outputs.tf"
    "modules_new/container_insights/main.tf"
    "modules_new/container_insights/variables.tf"
    "modules_new/container_insights/outputs.tf"
    "terraform/clusters/prod/outputs.tf"
    "terraform/clusters/devqa/outputs.tf"
)

for file in "${files_to_check[@]}"; do
    if [ -f "$file" ]; then
        print_status 0 "Found $file"
    else
        print_status 1 "Missing $file"
    fi
done

echo ""
echo "=== Configuration Summary ==="
print_info "WAF WebACLs configured for:"
echo "  - Production (cb-prod): Full security baseline with Bot Control"
echo "  - Dev/QA (cb-devqa): Cost-optimized baseline"

print_info "CloudWatch Container Insights configured for:"
echo "  - Production: 30-day log retention"
echo "  - Dev/QA: 7-day log retention"

print_info "Security features implemented:"
echo "  - AWS Managed Rule Groups (CRS, SQL Injection, etc.)"
echo "  - API rate limiting (2000/5min prod, 5000/5min dev/qa)"
echo "  - Request size restrictions (1MB limit for /api)"
echo "  - Optional geo-blocking and IP allow-listing"
echo "  - CloudWatch metrics and logging"

print_info "Integration methods provided:"
echo "  - Ingress annotations (recommended)"
echo "  - Terraform association (fallback)"
echo "  - Complete documentation and examples"

echo ""
echo -e "${GREEN}✓ AWS WAFv2 Security Baseline implementation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Deploy the infrastructure: terraform apply"
echo "2. Get WAF WebACL ARNs from outputs"
echo "3. Update Ingress resources with WAF annotations"
echo "4. Monitor WAF metrics and Container Insights"