#!/usr/bin/env bash
#
# manage-cluster.sh
# On-demand lifecycle control for EKS clusters
#
# Usage:
#   ./manage-cluster.sh up dev|qa|prod
#   ./manage-cluster.sh down dev|qa|prod
#
# Description:
#   - up: Creates the EKS cluster using eksctl config
#   - down: Deletes the EKS cluster and all associated resources
#   - Maps dev/qa to nonprod cluster (cluckn-bell-nonprod) in cluckin-bell-qa account
#   - Maps prod to prod cluster (cluckn-bell-prod) in cluckin-bell-prod account
#
# Prerequisites:
#   - AWS CLI configured with SSO profiles (cluckin-bell-qa, cluckin-bell-prod)
#   - eksctl installed
#   - Valid SSO session (use aws sso login --profile <profile>)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EKSCTL_DIR="${REPO_ROOT}/eksctl"
REGION="us-east-1"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_section() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Show usage
usage() {
    cat <<EOF
Usage: $0 <action> <environment>

Actions:
  up      Create/start the EKS cluster
  down    Delete/stop the EKS cluster

Environments:
  dev     Development environment (nonprod cluster in cluckin-bell-qa account)
  qa      QA environment (nonprod cluster in cluckin-bell-qa account)
  prod    Production environment (prod cluster in cluckin-bell-prod account)

Examples:
  $0 up qa       # Create nonprod cluster for QA
  $0 down qa     # Delete nonprod cluster
  $0 up prod     # Create prod cluster
  $0 down prod   # Delete prod cluster

Note: dev and qa share the same nonprod cluster (cluckn-bell-nonprod)
EOF
    exit 1
}

# Check prerequisites
check_prerequisites() {
    if ! command -v eksctl &> /dev/null; then
        log_error "eksctl not found. Please install it from https://eksctl.io/"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install it."
        exit 1
    fi
}

# Validate AWS profile and credentials
validate_credentials() {
    local profile=$1
    log_info "Validating AWS credentials for profile: ${profile}"
    
    if ! aws sts get-caller-identity --profile "${profile}" &> /dev/null; then
        log_error "Cannot authenticate with AWS profile: ${profile}"
        log_error "Please ensure SSO session is active:"
        log_error "  aws sso login --profile ${profile}"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --profile "${profile}" --query Account --output text)
    log_info "Authenticated with AWS account: ${account_id}"
}

# Map environment to cluster details
get_cluster_config() {
    local env=$1
    
    case "${env}" in
        dev|qa)
            CLUSTER_NAME="cluckn-bell-nonprod"
            AWS_PROFILE="cluckin-bell-qa"
            EKSCTL_CONFIG="${EKSCTL_DIR}/devqa-cluster.yaml"
            ACCOUNT_ID="264765154707"
            ;;
        prod)
            CLUSTER_NAME="cluckn-bell-prod"
            AWS_PROFILE="cluckin-bell-prod"
            EKSCTL_CONFIG="${EKSCTL_DIR}/prod-cluster.yaml"
            ACCOUNT_ID="346746763840"
            ;;
        *)
            log_error "Invalid environment: ${env}"
            usage
            ;;
    esac
    
    # Export for use by eksctl
    export AWS_PROFILE
}

# Create cluster
cluster_up() {
    local env=$1
    get_cluster_config "${env}"
    
    log_section "Starting cluster for ${env} environment"
    log_info "Cluster: ${CLUSTER_NAME}"
    log_info "Account: ${ACCOUNT_ID}"
    log_info "Profile: ${AWS_PROFILE}"
    log_info "Config: ${EKSCTL_CONFIG}"
    echo
    
    if [[ ! -f "${EKSCTL_CONFIG}" ]]; then
        log_error "Config file not found: ${EKSCTL_CONFIG}"
        exit 1
    fi
    
    validate_credentials "${AWS_PROFILE}"
    
    # Check if cluster already exists
    log_info "Checking if cluster already exists..."
    if eksctl get cluster --name "${CLUSTER_NAME}" --region "${REGION}" --profile "${AWS_PROFILE}" &> /dev/null; then
        log_warn "Cluster ${CLUSTER_NAME} already exists!"
        log_info "If you want to upgrade or modify it, use:"
        log_info "  eksctl upgrade cluster --config-file=${EKSCTL_CONFIG} --profile=${AWS_PROFILE} --approve"
        log_info "Or manually delete and recreate:"
        log_info "  $0 down ${env}"
        log_info "  $0 up ${env}"
        echo
        log_info "Current cluster status:"
        eksctl get cluster --name "${CLUSTER_NAME}" --region "${REGION}" --profile "${AWS_PROFILE}"
        exit 0
    fi
    
    # Create the cluster
    log_info "Creating cluster ${CLUSTER_NAME}..."
    log_warn "This will take 15-20 minutes..."
    echo
    
    eksctl create cluster --config-file="${EKSCTL_CONFIG}" --profile="${AWS_PROFILE}"
    
    echo
    log_section "Cluster Created Successfully!"
    log_info "Next steps:"
    log_info ""
    log_info "1. Update kubeconfig:"
    log_info "   aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION} --profile ${AWS_PROFILE}"
    log_info ""
    log_info "2. Get OIDC issuer URL (needed for IRSA):"
    log_info "   aws eks describe-cluster --name ${CLUSTER_NAME} --region ${REGION} --profile ${AWS_PROFILE} --query 'cluster.identity.oidc.issuer' --output text"
    log_info ""
    log_info "3. Bootstrap IRSA roles if needed:"
    log_info "   make irsa-nonprod   # For dev/qa"
    log_info "   make irsa-prod      # For prod"
    log_info ""
    log_info "4. To stop the cluster and minimize costs:"
    log_info "   $0 down ${env}"
    echo
}

# Delete cluster
cluster_down() {
    local env=$1
    get_cluster_config "${env}"
    
    log_section "Stopping cluster for ${env} environment"
    log_info "Cluster: ${CLUSTER_NAME}"
    log_info "Account: ${ACCOUNT_ID}"
    log_info "Profile: ${AWS_PROFILE}"
    echo
    
    validate_credentials "${AWS_PROFILE}"
    
    # Check if cluster exists
    log_info "Checking if cluster exists..."
    if ! eksctl get cluster --name "${CLUSTER_NAME}" --region "${REGION}" --profile "${AWS_PROFILE}" &> /dev/null; then
        log_warn "Cluster ${CLUSTER_NAME} does not exist or is already deleted."
        log_info "Nothing to do."
        exit 0
    fi
    
    # Confirm deletion
    log_warn "This will DELETE the cluster and all its resources!"
    log_warn "Cluster: ${CLUSTER_NAME}"
    log_warn "Region: ${REGION}"
    log_warn "Account: ${ACCOUNT_ID}"
    echo
    read -p "Are you sure you want to delete this cluster? (yes/no): " -r
    echo
    
    if [[ ! "${REPLY}" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Deletion cancelled."
        exit 0
    fi
    
    # Delete the cluster
    log_info "Deleting cluster ${CLUSTER_NAME}..."
    log_warn "This will take 10-15 minutes..."
    echo
    
    eksctl delete cluster --name "${CLUSTER_NAME}" --region "${REGION}" --profile "${AWS_PROFILE}"
    
    echo
    log_section "Cluster Deleted Successfully!"
    log_info "The cluster and all node groups have been removed."
    log_info "Control plane and node costs are now $0."
    log_info ""
    log_info "To recreate the cluster:"
    log_info "   $0 up ${env}"
    echo
}

# Main
main() {
    check_prerequisites
    
    if [[ $# -ne 2 ]]; then
        usage
    fi
    
    local action=$1
    local env=$2
    
    case "${action}" in
        up)
            cluster_up "${env}"
            ;;
        down)
            cluster_down "${env}"
            ;;
        *)
            log_error "Invalid action: ${action}"
            usage
            ;;
    esac
}

main "$@"
