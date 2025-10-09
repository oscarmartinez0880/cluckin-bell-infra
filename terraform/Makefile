# Makefile for EKS cluster management
# Usage: make help
#
# NOTE: EKS clusters are managed by eksctl, not Terraform.
# Use the eksctl configs in the eksctl/ directory at the repository root.

.PHONY: help kubeconfig-nonprod kubeconfig-prod

# Color output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
NC     := \033[0m

help: ## Show this help
	@echo "EKS Cluster Management Commands:"
	@echo
	@echo "  NOTE: EKS clusters are managed by eksctl."
	@echo "  Use 'make eks-create' from the repository root to create clusters."
	@echo
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

kubeconfig-nonprod: ## Update kubeconfig for nonprod cluster
	@echo "$(YELLOW)Updating kubeconfig for nonprod cluster...$(NC)"
	aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-nonprod --profile cluckin-bell-qa

kubeconfig-prod: ## Update kubeconfig for prod cluster
	@echo "$(YELLOW)Updating kubeconfig for prod cluster...$(NC)"
	aws eks update-kubeconfig --region us-east-1 --name cluckn-bell-prod --profile cluckin-bell-prod