#!/bin/bash
#
# create-clusters.sh
# Creates or upgrades EKS clusters using eksctl for cluckin-bell infrastructure
#
# Usage:
#   ./create-clusters.sh nonprod     # Create/upgrade nonprod cluster
#   ./create-clusters.sh prod        # Create/upgrade prod cluster
#   ./create-clusters.sh all         # Create/upgrade all clusters
#
# Prerequisites:
#   - eksctl installed (https://eksctl.io/)
#   - AWS CLI configured with appropriate profiles:
#     - cluckin-bell-qa for nonprod (account 264765154707)
#     - cluckin-bell-prod for prod (account 346746763840)
#   - VPCs and subnets already created via Terraform
#
# After cluster creation:
#   1. Note the OIDC issuer URL from the output
#   2. Run the IRSA bootstrap stack: cd stacks/irsa-bootstrap && terraform apply
#   3. Deploy controllers via Argo CD or Helm
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EKSCTL_DIR="${REPO_ROOT}/eksctl"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v eksctl &> /dev/null; then
        log_error "eksctl not found. Please install it from https://eksctl.io/"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install it."
        exit 1
    fi
    
    log_info "Prerequisites check passed"
}

# Validate AWS profile
validate_profile() {
    local profile=$1
    log_info "Validating AWS profile: ${profile}"
    
    if ! aws sts get-caller-identity --profile "${profile}" &> /dev/null; then
        log_error "Cannot authenticate with AWS profile: ${profile}"
        log_error "Please configure your AWS credentials or SSO login:"
        log_error "  aws sso login --profile ${profile}"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
    log_info "Authenticated with AWS account: ${account_id}"
}

# Get VPC ID from Terraform state
get_vpc_id() {
    local env=$1
    log_warn "VPC ID placeholder detected in eksctl config"
    log_warn "Please replace vpc-REPLACE_WITH_VPC_ID with actual VPC ID from Terraform outputs"
    log_warn "Similarly, replace subnet-REPLACE_WITH_SUBNET_* with actual subnet IDs"
    log_warn ""
    log_warn "To get VPC and subnet IDs:"
    log_warn "  cd terraform/clusters/devqa && terraform output"
    log_warn ""
    read -p "Have you updated the VPC and subnet IDs in the eksctl config? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        if [[ "${env}" == "nonprod" ]]; then
            log_error "Please update the VPC and subnet IDs in ${EKSCTL_DIR}/devqa-cluster.yaml"
        else
            log_error "Please update the VPC and subnet IDs in ${EKSCTL_DIR}/${env}-cluster.yaml"
        fi
        exit 1
    fi
}

# Create or upgrade nonprod cluster
create_nonprod_cluster() {
    log_info "=========================================="
    log_info "Creating/Upgrading Nonprod Cluster"
    log_info "=========================================="
    
    local profile="cluckin-bell-qa"
    local config_file="${EKSCTL_DIR}/devqa-cluster.yaml"
    
    if [[ ! -f "${config_file}" ]]; then
        log_error "Config file not found: ${config_file}"
        exit 1
    fi
    
    validate_profile "${profile}"
    get_vpc_id "nonprod"
    
    log_info "Checking if cluster already exists..."
    if eksctl get cluster --name cluckn-bell-nonprod --region us-east-1 --profile "${profile}" &> /dev/null; then
        log_warn "Cluster cluckn-bell-nonprod already exists"
        log_info "Running upgrade instead..."
        eksctl upgrade cluster --config-file="${config_file}" --profile="${profile}" --approve
    else
        log_info "Creating new cluster cluckn-bell-nonprod..."
        eksctl create cluster --config-file="${config_file}" --profile="${profile}"
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "Nonprod Cluster Ready!"
    log_info "=========================================="
    log_info "Next steps:"
    log_info "1. Get the OIDC issuer URL:"
    log_info "   aws eks describe-cluster --name cluckn-bell-nonprod --region us-east-1 --profile ${profile} --query 'cluster.identity.oidc.issuer' --output text"
    log_info ""
    log_info "2. Bootstrap IRSA roles (see stacks/irsa-bootstrap/)"
    log_info ""
    log_info "3. Update kubeconfig:"
    log_info "   aws eks update-kubeconfig --name cluckn-bell-nonprod --region us-east-1 --profile ${profile}"
    log_info ""
}

# Create or upgrade prod cluster
create_prod_cluster() {
    log_info "=========================================="
    log_info "Creating/Upgrading Prod Cluster"
    log_info "=========================================="
    
    local profile="cluckin-bell-prod"
    local config_file="${EKSCTL_DIR}/prod-cluster.yaml"
    
    if [[ ! -f "${config_file}" ]]; then
        log_error "Config file not found: ${config_file}"
        exit 1
    fi
    
    validate_profile "${profile}"
    get_vpc_id "prod"
    
    log_info "Checking if cluster already exists..."
    if eksctl get cluster --name cluckn-bell-prod --region us-east-1 --profile "${profile}" &> /dev/null; then
        log_warn "Cluster cluckn-bell-prod already exists"
        log_info "Running upgrade instead..."
        eksctl upgrade cluster --config-file="${config_file}" --profile="${profile}" --approve
    else
        log_info "Creating new cluster cluckn-bell-prod..."
        eksctl create cluster --config-file="${config_file}" --profile="${profile}"
    fi
    
    log_info ""
    log_info "=========================================="
    log_info "Prod Cluster Ready!"
    log_info "=========================================="
    log_info "Next steps:"
    log_info "1. Get the OIDC issuer URL:"
    log_info "   aws eks describe-cluster --name cluckn-bell-prod --region us-east-1 --profile ${profile} --query 'cluster.identity.oidc.issuer' --output text"
    log_info ""
    log_info "2. Bootstrap IRSA roles (see stacks/irsa-bootstrap/)"
    log_info ""
    log_info "3. Update kubeconfig:"
    log_info "   aws eks update-kubeconfig --name cluckn-bell-prod --region us-east-1 --profile ${profile}"
    log_info ""
}

# Main
main() {
    check_prerequisites
    
    local action=${1:-}
    
    case "${action}" in
        nonprod)
            create_nonprod_cluster
            ;;
        prod)
            create_prod_cluster
            ;;
        all)
            create_nonprod_cluster
            echo ""
            echo ""
            create_prod_cluster
            ;;
        *)
            log_error "Usage: $0 {nonprod|prod|all}"
            exit 1
            ;;
    esac
    
    log_info ""
    log_info "=========================================="
    log_info "All Done!"
    log_info "=========================================="
    log_info "Remember: Terraform no longer manages EKS clusters by default"
    log_info "Use eksctl for cluster lifecycle operations"
    log_info "Use Terraform's IRSA bootstrap stack for IAM roles post-cluster creation"
}

main "$@"
