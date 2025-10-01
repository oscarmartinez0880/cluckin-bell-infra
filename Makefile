.PHONY: help check-tools
.PHONY: sso-devqa sso-prod
.PHONY: accounts-devqa accounts-prod dns vpc
.PHONY: iam-nonprod iam-prod
.PHONY: infra-nonprod infra-prod
.PHONY: eks-create
.PHONY: irsa-nonprod irsa-prod irsa-bootstrap
.PHONY: outputs-vpc
.PHONY: init fmt fmt-check validate plan plan-out apply apply-auto apply-plan destroy clean show refresh
.PHONY: workspace-list workspace-new workspace-select lint ci
.PHONY: test-ecr-dry test-ecr-dev test-ecr-qa test-ecr-prod test-ecr-all test-ecr-status test-ecr-collect test-ecr-help

###############################################################################
# Variables (overridable via environment)
###############################################################################
REGION ?= us-east-1
DEVQA_PROFILE ?= cluckin-bell-qa
PROD_PROFILE ?= cluckin-bell-prod
TF ?= terraform
NONPROD_CLUSTER ?= cluckn-bell-nonprod
PROD_CLUSTER ?= cluckn-bell-prod

###############################################################################
# Default target
###############################################################################
help: ## Show this help message
	@echo "==========================================="
	@echo "Cluckin Bell Infrastructure Makefile"
	@echo "==========================================="
	@echo ""
	@echo "Operating Model:"
	@echo "  - Terraform for foundational AWS (accounts, DNS, VPC, node IAM)"
	@echo "  - eksctl for EKS cluster lifecycle (v1.33)"
	@echo "  - Terraform for post-cluster IRSA bootstrap"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

###############################################################################
# Tool checking
###############################################################################
check-tools: ## Verify required tools are installed
	@echo "Checking required tools..."
	@command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found"; exit 1; }
	@command -v eksctl >/dev/null 2>&1 || { echo "ERROR: eksctl not found"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }
	@command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found"; exit 1; }
	@command -v $(TF) >/dev/null 2>&1 || { echo "ERROR: terraform not found"; exit 1; }
	@echo "✓ All required tools are installed"

###############################################################################
# AWS SSO Login
###############################################################################
sso-devqa: ## Login to AWS SSO for devqa account
	aws sso login --profile $(DEVQA_PROFILE)

sso-prod: ## Login to AWS SSO for prod account
	aws sso login --profile $(PROD_PROFILE)

###############################################################################
# Accounts-level IAM/ECR/OIDC
###############################################################################
accounts-devqa: ## Apply accounts-level resources for devqa
	cd terraform/accounts/devqa && \
		$(TF) init && \
		$(TF) apply -auto-approve -var "region=$(REGION)"

accounts-prod: ## Apply accounts-level resources for prod
	cd terraform/accounts/prod && \
		$(TF) init && \
		$(TF) apply -auto-approve -var "region=$(REGION)"

###############################################################################
# DNS scaffolding
###############################################################################
dns: ## Apply DNS resources (dev/qa subzones)
	@echo "NOTE: After applying, paste NS records for dev/qa delegation into prod tfvars if needed"
	cd terraform/dns && \
		$(TF) init && \
		$(TF) apply -auto-approve

###############################################################################
# Networking (VPCs only, no EKS clusters)
###############################################################################
vpc: ## Apply VPC resources without EKS clusters
	cd terraform/clusters/devqa && \
		$(TF) init && \
		$(TF) apply -auto-approve \
			-var "region=$(REGION)" \
			-var "devqa_profile=$(DEVQA_PROFILE)" \
			-var "prod_profile=$(PROD_PROFILE)" \
			-var "manage_eks=false"

###############################################################################
# Node IAM roles
###############################################################################
iam-nonprod: ## Apply node IAM roles for nonprod
	cd envs/nonprod && \
		$(TF) init -backend-config=backend.hcl && \
		$(TF) apply -auto-approve

iam-prod: ## Apply node IAM roles for prod
	cd envs/prod && \
		$(TF) init -backend-config=backend.hcl && \
		$(TF) apply -auto-approve

###############################################################################
# One-shot infrastructure targets
###############################################################################
infra-nonprod: sso-devqa accounts-devqa vpc iam-nonprod ## Deploy all foundational nonprod infrastructure

infra-prod: sso-prod accounts-prod vpc iam-prod ## Deploy all foundational prod infrastructure

###############################################################################
# EKS cluster creation via eksctl
###############################################################################
eks-create: ## Create/upgrade EKS clusters using eksctl (requires VPCs exist)
	@echo "Creating EKS clusters via eksctl..."
	@echo "This will handle SSO login internally and apply eksctl YAMLs"
	./scripts/eks/create-clusters.sh all

###############################################################################
# IRSA bootstrap (post-cluster)
###############################################################################
irsa-nonprod: ## Bootstrap IRSA roles for nonprod cluster
	@echo "Bootstrapping IRSA for nonprod cluster: $(NONPROD_CLUSTER)"
	@OIDC_URL=$$(aws eks describe-cluster --name $(NONPROD_CLUSTER) --region $(REGION) --profile $(DEVQA_PROFILE) --query 'cluster.identity.oidc.issuer' --output text 2>/dev/null || echo ""); \
	if [ -z "$$OIDC_URL" ]; then \
		echo "ERROR: Could not get OIDC issuer URL. Cluster may not exist yet."; \
		echo "Run 'make eks-create' first to create the cluster."; \
		exit 1; \
	fi; \
	cd stacks/irsa-bootstrap && \
		$(TF) init && \
		$(TF) apply -auto-approve \
			-var "cluster_name=$(NONPROD_CLUSTER)" \
			-var "region=$(REGION)" \
			-var "aws_profile=$(DEVQA_PROFILE)" \
			-var "oidc_issuer_url=$$OIDC_URL" \
			-var "environment=nonprod"

irsa-prod: ## Bootstrap IRSA roles for prod cluster
	@echo "Bootstrapping IRSA for prod cluster: $(PROD_CLUSTER)"
	@OIDC_URL=$$(aws eks describe-cluster --name $(PROD_CLUSTER) --region $(REGION) --profile $(PROD_PROFILE) --query 'cluster.identity.oidc.issuer' --output text 2>/dev/null || echo ""); \
	if [ -z "$$OIDC_URL" ]; then \
		echo "ERROR: Could not get OIDC issuer URL. Cluster may not exist yet."; \
		echo "Run 'make eks-create' first to create the cluster."; \
		exit 1; \
	fi; \
	cd stacks/irsa-bootstrap && \
		$(TF) init && \
		$(TF) apply -auto-approve \
			-var "cluster_name=$(PROD_CLUSTER)" \
			-var "region=$(REGION)" \
			-var "aws_profile=$(PROD_PROFILE)" \
			-var "oidc_issuer_url=$$OIDC_URL" \
			-var "environment=prod"

irsa-bootstrap: irsa-nonprod irsa-prod ## Bootstrap IRSA roles for all clusters

###############################################################################
# Helper targets
###############################################################################
outputs-vpc: ## Print VPC outputs from terraform/clusters/devqa (for eksctl YAMLs)
	@echo "VPC Outputs (use these to fill eksctl YAML configs):"
	@$(TF) -chdir=terraform/clusters/devqa output -json

###############################################################################
# Standard Terraform targets (for use in specific directories)
###############################################################################
init: ## Initialize Terraform
	terraform init

fmt: ## Format Terraform files
	terraform fmt -recursive

fmt-check: ## Check if Terraform files are formatted
	terraform fmt -check -recursive

validate: ## Validate Terraform configuration
	terraform validate

plan: ## Generate and show an execution plan
	terraform plan

plan-out: ## Generate and save an execution plan
	terraform plan -out=tfplan

apply: ## Apply the Terraform plan
	terraform apply

apply-auto: ## Apply the Terraform plan without interactive approval
	terraform apply -auto-approve

apply-plan: ## Apply a saved plan
	terraform apply tfplan

destroy: ## Destroy Terraform-managed infrastructure
	terraform destroy

clean: ## Clean up temporary files
	rm -f tfplan
	rm -f terraform.tfstate.backup

show: ## Show the current state
	terraform show

refresh: ## Refresh the Terraform state
	terraform refresh

workspace-list: ## List Terraform workspaces
	terraform workspace list

workspace-new: ## Create a new workspace (usage: make workspace-new WORKSPACE=name)
	terraform workspace new $(WORKSPACE)

workspace-select: ## Select a workspace (usage: make workspace-select WORKSPACE=name)
	terraform workspace select $(WORKSPACE)

lint: fmt-check validate ## Run linting (format check and validate)

ci: init lint plan ## Run CI pipeline (init, lint, plan)

###############################################################################
# ECR Testing targets
###############################################################################
test-ecr-dry: ## Run ECR workflow tests in dry-run mode
	@echo "Running ECR tests in dry-run mode..."
	./scripts/run-ecr-tests.sh run-tests --environment all --application all --dry-run true

test-ecr-dev: ## Run ECR workflow tests for dev environment
	@echo "Running ECR tests for dev environment..."
	./scripts/run-ecr-tests.sh run-tests --environment dev --application all --dry-run false --wait

test-ecr-qa: ## Run ECR workflow tests for qa environment
	@echo "Running ECR tests for qa environment..."
	./scripts/run-ecr-tests.sh run-tests --environment qa --application all --dry-run false --wait

test-ecr-prod: ## Run ECR workflow tests for prod environment
	@echo "Running ECR tests for prod environment..."
	./scripts/run-ecr-tests.sh run-tests --environment prod --application all --dry-run false --wait

test-ecr-all: ## Run ECR workflow tests for all environments
	@echo "Running ECR tests for all environments..."
	./scripts/run-ecr-tests.sh run-tests --environment all --application all --dry-run false --wait

test-ecr-status: ## Check status of ECR workflow tests
	./scripts/run-ecr-tests.sh check-status

test-ecr-collect: ## Collect ECR test results and generate reports
	./scripts/collect-ecr-results.sh --include-screenshots

test-ecr-help: ## Show ECR testing help
	./scripts/run-ecr-tests.sh help