#!/bin/bash

# Cluckin Bell Account-Level Infrastructure Deployment Script
# This script deploys the account-level infrastructure to both AWS accounts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to deploy a specific account
deploy_account() {
    local account=$1
    local account_dir="$TERRAFORM_DIR/accounts/$account"
    
    print_status "Deploying $account account infrastructure..."
    
    if [ ! -d "$account_dir" ]; then
        print_error "Account directory $account_dir does not exist"
        return 1
    fi
    
    cd "$account_dir"
    
    # Initialize Terraform
    print_status "Initializing Terraform for $account account..."
    if ! terraform init; then
        print_error "Failed to initialize Terraform for $account account"
        return 1
    fi
    
    # Validate configuration
    print_status "Validating Terraform configuration for $account account..."
    if ! terraform validate; then
        print_error "Terraform configuration validation failed for $account account"
        return 1
    fi
    
    # Plan deployment
    print_status "Planning Terraform deployment for $account account..."
    if ! terraform plan -out="$account.tfplan"; then
        print_error "Terraform plan failed for $account account"
        return 1
    fi
    
    # Ask for confirmation unless auto-approve is set
    if [ "$AUTO_APPROVE" != "true" ]; then
        echo
        read -p "Do you want to apply the $account account infrastructure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Skipping $account account deployment"
            return 0
        fi
    fi
    
    # Apply deployment
    print_status "Applying Terraform configuration for $account account..."
    if ! terraform apply "$account.tfplan"; then
        print_error "Terraform apply failed for $account account"
        return 1
    fi
    
    print_success "$account account infrastructure deployed successfully"
    
    # Show outputs
    print_status "Terraform outputs for $account account:"
    terraform output -json | jq '.'
    
    return 0
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [ACCOUNTS...]"
    echo
    echo "Deploy Cluckin Bell account-level infrastructure"
    echo
    echo "Options:"
    echo "  -a, --auto-approve    Auto-approve Terraform apply (skip confirmation)"
    echo "  -h, --help           Show this help message"
    echo
    echo "Accounts:"
    echo "  devqa                Deploy DevQA account (264765154707)"
    echo "  prod                 Deploy Production account (346746763840)"
    echo "  all                  Deploy both accounts (default)"
    echo
    echo "Examples:"
    echo "  $0                   # Deploy both accounts with confirmation"
    echo "  $0 devqa            # Deploy only DevQA account"
    echo "  $0 -a prod          # Deploy Production account without confirmation"
    echo "  $0 --auto-approve all  # Deploy both accounts without confirmation"
}

# Parse command line arguments
AUTO_APPROVE=false
ACCOUNTS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        devqa|prod|all)
            ACCOUNTS+=("$1")
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Default to all accounts if none specified
if [ ${#ACCOUNTS[@]} -eq 0 ]; then
    ACCOUNTS=("all")
fi

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed or not in PATH"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed or not in PATH"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    print_warning "jq is not installed - output formatting will be limited"
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured or invalid"
    print_error "Please configure AWS CLI with: aws configure"
    exit 1
fi

print_success "Prerequisites check passed"

# Deploy accounts
FAILED_ACCOUNTS=()

for account in "${ACCOUNTS[@]}"; do
    case $account in
        devqa)
            if ! deploy_account "devqa"; then
                FAILED_ACCOUNTS+=("devqa")
            fi
            ;;
        prod)
            if ! deploy_account "prod"; then
                FAILED_ACCOUNTS+=("prod")
            fi
            ;;
        all)
            if ! deploy_account "devqa"; then
                FAILED_ACCOUNTS+=("devqa")
            fi
            if ! deploy_account "prod"; then
                FAILED_ACCOUNTS+=("prod")
            fi
            ;;
        *)
            print_error "Unknown account: $account"
            FAILED_ACCOUNTS+=("$account")
            ;;
    esac
done

# Summary
echo
print_status "Deployment Summary:"
if [ ${#FAILED_ACCOUNTS[@]} -eq 0 ]; then
    print_success "All requested accounts deployed successfully"
    exit 0
else
    print_error "Failed to deploy the following accounts: ${FAILED_ACCOUNTS[*]}"
    exit 1
fi