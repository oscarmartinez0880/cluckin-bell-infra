#!/bin/bash

# validate-eks-setup.sh
# Script to validate prerequisites before deploying EKS clusters

set -e

echo "🔍 Validating EKS cluster setup prerequisites..."
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check AWS CLI
echo "1. Checking AWS CLI..."
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1 | head -n1)
    success "AWS CLI found: $AWS_VERSION"
else
    error "AWS CLI not found. Please install AWS CLI."
    exit 1
fi

echo

# Check Terraform
echo "2. Checking Terraform..."
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version | head -n1)
    success "Terraform found: $TERRAFORM_VERSION"
else
    error "Terraform not found. Please install Terraform >= 1.0"
    exit 1
fi

echo

# Check AWS profiles
echo "3. Checking AWS profiles..."

if aws configure list-profiles | grep -q "cluckin-bell-qa"; then
    success "AWS profile 'cluckin-bell-qa' found"
else
    error "AWS profile 'cluckin-bell-qa' not found. Please configure it."
fi

if aws configure list-profiles | grep -q "cluckin-bell-prod"; then
    success "AWS profile 'cluckin-bell-prod' found"
else
    error "AWS profile 'cluckin-bell-prod' not found. Please configure it."
fi

echo

# Validate nonprod subnets
echo "4. Validating nonprod subnets..."
NONPROD_SUBNETS=(
    "subnet-09a601564fef30599"
    "subnet-0e428ee488b3accac" 
    "subnet-00205cdb6865588ac"
    "subnet-0d1a90b43e2855061"
    "subnet-0e408dd3b79d3568b"
    "subnet-00d5249fbe0695848"
)

echo "Checking nonprod subnet access..."
for subnet in "${NONPROD_SUBNETS[@]}"; do
    if aws ec2 describe-subnets --subnet-ids "$subnet" --profile cluckin-bell-qa &> /dev/null; then
        success "Subnet $subnet accessible"
    else
        error "Subnet $subnet not accessible or doesn't exist"
    fi
done

# Get VPC ID for nonprod
echo "Getting nonprod VPC ID..."
NONPROD_VPC_ID=$(aws ec2 describe-subnets \
    --subnet-ids "${NONPROD_SUBNETS[0]}" \
    --profile cluckin-bell-qa \
    --query 'Subnets[0].VpcId' \
    --output text 2>/dev/null) || {
    error "Failed to get nonprod VPC ID"
}

if [[ -n "$NONPROD_VPC_ID" && "$NONPROD_VPC_ID" != "None" ]]; then
    success "Nonprod VPC ID: $NONPROD_VPC_ID"
else
    error "Could not determine nonprod VPC ID"
fi

echo

# Validate prod subnets
echo "5. Validating prod subnets..."
PROD_SUBNETS=(
    "subnet-058d9ae9ff9399cb6"
    "subnet-0fd7aac0afed270b0"
    "subnet-06b04efdad358c264"
    "subnet-09722cf26237fc552"
    "subnet-0fb6f763ab136eb0b" 
    "subnet-0bbb317a18c2a6386"
)

echo "Checking prod subnet access..."
for subnet in "${PROD_SUBNETS[@]}"; do
    if aws ec2 describe-subnets --subnet-ids "$subnet" --profile cluckin-bell-prod &> /dev/null; then
        success "Subnet $subnet accessible"
    else
        error "Subnet $subnet not accessible or doesn't exist"
    fi
done

# Get VPC ID for prod
echo "Getting prod VPC ID..."
PROD_VPC_ID=$(aws ec2 describe-subnets \
    --subnet-ids "${PROD_SUBNETS[0]}" \
    --profile cluckin-bell-prod \
    --query 'Subnets[0].VpcId' \
    --output text 2>/dev/null) || {
    error "Failed to get prod VPC ID"
}

if [[ -n "$PROD_VPC_ID" && "$PROD_VPC_ID" != "None" ]]; then
    success "Prod VPC ID: $PROD_VPC_ID"
else
    error "Could not determine prod VPC ID"
fi

echo

# Check S3 buckets
echo "6. Checking S3 backend buckets..."

if aws s3 ls "s3://cluckn-bell-tfstate-nonprod" --profile cluckin-bell-qa &> /dev/null; then
    success "S3 bucket 'cluckn-bell-tfstate-nonprod' accessible"
else
    warning "S3 bucket 'cluckn-bell-tfstate-nonprod' not accessible or doesn't exist"
fi

if aws s3 ls "s3://cluckn-bell-tfstate-prod" --profile cluckin-bell-prod &> /dev/null; then
    success "S3 bucket 'cluckn-bell-tfstate-prod' accessible"
else
    warning "S3 bucket 'cluckn-bell-tfstate-prod' not accessible or doesn't exist"
fi

echo

# Generate sample terraform commands
echo "7. Sample Terraform commands:"
echo

if [[ -n "$NONPROD_VPC_ID" && "$NONPROD_VPC_ID" != "None" ]]; then
    echo "📋 Nonprod cluster deployment:"
    echo "cd terraform/nonprod-eks"
    echo "terraform init -backend-config=backend.hcl"
    echo "terraform plan \\"
    echo "  -var 'aws_profile=cluckin-bell-qa' \\"
    echo "  -var 'vpc_id=$NONPROD_VPC_ID' \\"
    echo "  -var 'public_subnet_ids=[\"subnet-09a601564fef30599\",\"subnet-0e428ee488b3accac\",\"subnet-00205cdb6865588ac\"]' \\"
    echo "  -var 'private_subnet_ids=[\"subnet-0d1a90b43e2855061\",\"subnet-0e408dd3b79d3568b\",\"subnet-00d5249fbe0695848\"]'"
    echo
fi

if [[ -n "$PROD_VPC_ID" && "$PROD_VPC_ID" != "None" ]]; then
    echo "📋 Prod cluster deployment:"
    echo "cd terraform/prod-eks"
    echo "terraform init -backend-config=backend.hcl"
    echo "terraform plan \\"
    echo "  -var 'aws_profile=cluckin-bell-prod' \\"
    echo "  -var 'vpc_id=$PROD_VPC_ID' \\"
    echo "  -var 'public_subnet_ids=[\"subnet-058d9ae9ff9399cb6\",\"subnet-0fd7aac0afed270b0\",\"subnet-06b04efdad358c264\"]' \\"
    echo "  -var 'private_subnet_ids=[\"subnet-09722cf26237fc552\",\"subnet-0fb6f763ab136eb0b\",\"subnet-0bbb317a18c2a6386\"]'"
    echo
fi

echo "🎉 Validation complete! You can now proceed with terraform deployment."
echo "📚 See terraform/eks-recreate-README.md for detailed usage instructions."