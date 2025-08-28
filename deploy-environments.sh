#!/bin/bash

# Multi-Environment EKS Deployment Script
# Deploys dev, qa, and prod EKS clusters with ArgoCD GitOps

set -e

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

# Function to deploy a single environment
deploy_environment() {
    local env=$1
    print_status "Deploying $env environment..."
    
    cd stacks/environments/$env
    
    print_status "Initializing Terraform for $env..."
    terraform init
    
    print_status "Planning $env deployment..."
    terraform plan -out=tfplan
    
    print_status "Applying $env deployment..."
    terraform apply tfplan
    
    print_success "$env environment deployed successfully!"
    
    # Display key outputs
    print_status "$env Environment Details:"
    echo "Cluster Name: $(terraform output -raw cluster_name)"
    echo "Namespace: $(terraform output -raw namespace)"
    echo "ArgoCD URL: $(terraform output -raw argocd_server_url)"
    
    cd - > /dev/null
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed. You'll need it to interact with the clusters."
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [ENVIRONMENT|all] [OPTIONS]"
    echo ""
    echo "ENVIRONMENT:"
    echo "  dev     Deploy development environment only"
    echo "  qa      Deploy QA environment only" 
    echo "  prod    Deploy production environment only"
    echo "  all     Deploy all environments (default)"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  --auto-approve Auto-approve Terraform plans (use with caution)"
    echo ""
    echo "Examples:"
    echo "  $0              # Deploy all environments"
    echo "  $0 dev          # Deploy dev environment only"
    echo "  $0 all          # Deploy all environments"
}

# Parse command line arguments
ENVIRONMENT="all"
AUTO_APPROVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        dev|qa|prod|all)
            ENVIRONMENT="$1"
            shift
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_status "Multi-Environment EKS Deployment"
    print_status "================================="
    
    check_prerequisites
    
    case $ENVIRONMENT in
        dev)
            deploy_environment "dev"
            ;;
        qa)
            deploy_environment "qa"
            ;;
        prod)
            deploy_environment "prod"
            ;;
        all)
            print_status "Deploying all environments: dev, qa, prod"
            deploy_environment "dev"
            deploy_environment "qa"
            deploy_environment "prod"
            
            print_success "All environments deployed successfully!"
            print_status "Summary:"
            print_status "- dev cluster: cb-dev-use1"
            print_status "- qa cluster: cb-qa-use1"
            print_status "- prod cluster: cb-prod-use1"
            print_status "- All clusters configured with ArgoCD for GitOps"
            ;;
        *)
            print_error "Invalid environment: $ENVIRONMENT"
            show_usage
            exit 1
            ;;
    esac
    
    print_success "Deployment completed!"
    print_status "Next steps:"
    echo "1. Access ArgoCD web interface using the provided URLs"
    echo "2. Get admin password: kubectl -n cluckin-bell get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo "3. Set up your applications in the oscarmartinez0880/cluckin-bell repository"
}

# Execute main function
main "$@"