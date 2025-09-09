# Makefile for EKS cluster management
# Usage: make help

.PHONY: help validate init-nonprod init-prod plan-nonprod plan-prod apply-nonprod apply-prod clean

# Color output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m

help: ## Show this help
	@echo "EKS Cluster Management Commands:"
	@echo
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo
	@echo "Examples:"
	@echo "  make validate                    # Validate prerequisites"
	@echo "  make init-nonprod               # Initialize nonprod environment"
	@echo "  make plan-nonprod VPC_ID=vpc-xxx # Plan nonprod deployment"
	@echo "  make apply-nonprod VPC_ID=vpc-xxx # Apply nonprod deployment"

validate: ## Validate prerequisites and environment setup
	@echo "$(YELLOW)Validating EKS setup prerequisites...$(NC)"
	@./validate-eks-setup.sh

init-nonprod: ## Initialize Terraform for nonprod environment
	@echo "$(YELLOW)Initializing nonprod environment...$(NC)"
	cd nonprod-eks && terraform init -backend-config=backend.hcl

init-prod: ## Initialize Terraform for prod environment  
	@echo "$(YELLOW)Initializing prod environment...$(NC)"
	cd prod-eks && terraform init -backend-config=backend.hcl

plan-nonprod: ## Plan nonprod EKS cluster deployment (requires VPC_ID)
ifndef VPC_ID
	$(error VPC_ID is required. Usage: make plan-nonprod VPC_ID=vpc-12345678)
endif
	@echo "$(YELLOW)Planning nonprod EKS cluster deployment...$(NC)"
	cd nonprod-eks && terraform plan \
		-var 'aws_profile=cluckin-bell-qa' \
		-var 'vpc_id=$(VPC_ID)' \
		-var 'public_subnet_ids=["subnet-09a601564fef30599","subnet-0e428ee488b3accac","subnet-00205cdb6865588ac"]' \
		-var 'private_subnet_ids=["subnet-0d1a90b43e2855061","subnet-0e408dd3b79d3568b","subnet-00d5249fbe0695848"]'

plan-prod: ## Plan prod EKS cluster deployment (requires VPC_ID)
ifndef VPC_ID
	$(error VPC_ID is required. Usage: make plan-prod VPC_ID=vpc-87654321)
endif
	@echo "$(YELLOW)Planning prod EKS cluster deployment...$(NC)"
	cd prod-eks && terraform plan \
		-var 'aws_profile=cluckin-bell-prod' \
		-var 'vpc_id=$(VPC_ID)' \
		-var 'public_subnet_ids=["subnet-058d9ae9ff9399cb6","subnet-0fd7aac0afed270b0","subnet-06b04efdad358c264"]' \
		-var 'private_subnet_ids=["subnet-09722cf26237fc552","subnet-0fb6f763ab136eb0b","subnet-0bbb317a18c2a6386"]'

apply-nonprod: ## Apply nonprod EKS cluster deployment (requires VPC_ID)
ifndef VPC_ID
	$(error VPC_ID is required. Usage: make apply-nonprod VPC_ID=vpc-12345678)
endif
	@echo "$(RED)Applying nonprod EKS cluster deployment...$(NC)"
	@echo "$(RED)This will create real AWS resources!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd nonprod-eks && terraform apply \
			-var 'aws_profile=cluckin-bell-qa' \
			-var 'vpc_id=$(VPC_ID)' \
			-var 'public_subnet_ids=["subnet-09a601564fef30599","subnet-0e428ee488b3accac","subnet-00205cdb6865588ac"]' \
			-var 'private_subnet_ids=["subnet-0d1a90b43e2855061","subnet-0e408dd3b79d3568b","subnet-00d5249fbe0695848"]'; \
	fi

apply-prod: ## Apply prod EKS cluster deployment (requires VPC_ID)
ifndef VPC_ID
	$(error VPC_ID is required. Usage: make apply-prod VPC_ID=vpc-87654321)
endif
	@echo "$(RED)Applying prod EKS cluster deployment...$(NC)"
	@echo "$(RED)This will create real AWS resources in PRODUCTION!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd prod-eks && terraform apply \
			-var 'aws_profile=cluckin-bell-prod' \
			-var 'vpc_id=$(VPC_ID)' \
			-var 'public_subnet_ids=["subnet-058d9ae9ff9399cb6","subnet-0fd7aac0afed270b0","subnet-06b04efdad358c264"]' \
			-var 'private_subnet_ids=["subnet-09722cf26237fc552","subnet-0fb6f763ab136eb0b","subnet-0bbb317a18c2a6386"]'; \
	fi

get-vpc-ids: ## Get VPC IDs for the configured subnets
	@echo "$(YELLOW)Getting VPC IDs...$(NC)"
	@echo "Nonprod VPC ID:"
	@aws ec2 describe-subnets --subnet-ids subnet-09a601564fef30599 --profile cluckin-bell-qa --query 'Subnets[0].VpcId' --output text 2>/dev/null || echo "Error: Cannot access nonprod subnets"
	@echo "Prod VPC ID:"
	@aws ec2 describe-subnets --subnet-ids subnet-058d9ae9ff9399cb6 --profile cluckin-bell-prod --query 'Subnets[0].VpcId' --output text 2>/dev/null || echo "Error: Cannot access prod subnets"

kubeconfig-nonprod: ## Update kubeconfig for nonprod cluster
	@echo "$(YELLOW)Updating kubeconfig for nonprod cluster...$(NC)"
	aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-nonprod --profile cluckin-bell-qa

kubeconfig-prod: ## Update kubeconfig for prod cluster
	@echo "$(YELLOW)Updating kubeconfig for prod cluster...$(NC)"
	aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-prod --profile cluckin-bell-prod

clean: ## Clean up .terraform directories
	@echo "$(YELLOW)Cleaning up .terraform directories...$(NC)"
	rm -rf nonprod-eks/.terraform nonprod-eks/.terraform.lock.hcl
	rm -rf prod-eks/.terraform prod-eks/.terraform.lock.hcl

clean-all: clean ## Clean up all generated files (use with caution)
	@echo "$(RED)Cleaning up all generated files...$(NC)"
	rm -f nonprod-eks/terraform.tfvars nonprod-eks/*.tfplan
	rm -f prod-eks/terraform.tfvars prod-eks/*.tfplan