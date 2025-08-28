.PHONY: help init fmt validate plan apply clean

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

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

# ECR Testing targets
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