.PHONY: help check-tools
.PHONY: login-nonprod login-prod
.PHONY: sso-devqa sso-prod
.PHONY: accounts-devqa accounts-prod dns vpc
.PHONY: iam-nonprod iam-prod
.PHONY: infra-nonprod infra-prod
.PHONY: tf-init tf-plan tf-apply tf-destroy
.PHONY: eks-create eks-upgrade eks-delete
.PHONY: dr-provision-prod
.PHONY: outputs
.PHONY: irsa-nonprod irsa-prod irsa-bootstrap
.PHONY: outputs-vpc
.PHONY: init fmt fmt-check validate plan plan-out apply apply-auto apply-plan destroy clean show refresh
.PHONY: workspace-list workspace-new workspace-select lint ci
.PHONY: test-ecr-dry test-ecr-dev test-ecr-qa test-ecr-prod test-ecr-all test-ecr-status test-ecr-collect test-ecr-help
.PHONY: dr-provision-prod dr-status-prod

###############################################################################
# Variables (overridable via environment)
###############################################################################
REGION ?= us-east-1
ENV ?= nonprod
DEVQA_PROFILE ?= cluckin-bell-qa
PROD_PROFILE ?= cluckin-bell-prod
TF ?= terraform
NONPROD_CLUSTER ?= cluckn-bell-nonprod
PROD_CLUSTER ?= cluckn-bell-prod

# Account IDs for reference
NONPROD_ACCOUNT ?= 264765154707
PROD_ACCOUNT ?= 346746763840

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
	@echo "  - eksctl for EKS cluster lifecycle (>= v1.33)"
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
# AWS SSO Login (new simplified targets)
###############################################################################
login-nonprod: ## Login to AWS SSO for nonprod account
	@echo "Logging into nonprod account ($(NONPROD_ACCOUNT))..."
	aws sso login --profile $(DEVQA_PROFILE)
	@echo "✓ Logged in to nonprod account"

login-prod: ## Login to AWS SSO for prod account
	@echo "Logging into prod account ($(PROD_ACCOUNT))..."
	aws sso login --profile $(PROD_PROFILE)
	@echo "✓ Logged in to prod account"

###############################################################################
# AWS SSO Login (legacy targets for backward compatibility)
###############################################################################
sso-devqa: login-nonprod ## Login to AWS SSO for devqa account (alias for login-nonprod)

sso-prod: login-prod ## Login to AWS SSO for prod account (alias for login-prod)

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
# Terraform workflow targets (new parameterized targets)
###############################################################################
tf-init: ## Initialize Terraform for environment (usage: make tf-init ENV=nonprod REGION=us-east-1)
	@echo "Initializing Terraform for $(ENV) in $(REGION)..."
	@if [ "$(ENV)" = "nonprod" ]; then \
		cd envs/nonprod && $(TF) init -backend-config=backend.hcl; \
	elif [ "$(ENV)" = "prod" ]; then \
		cd envs/prod && $(TF) init -backend-config=backend.hcl; \
	else \
		echo "ERROR: ENV must be 'nonprod' or 'prod'"; \
		exit 1; \
	fi

tf-plan: ## Plan Terraform changes (usage: make tf-plan ENV=nonprod REGION=us-east-1)
	@echo "Planning Terraform changes for $(ENV) in $(REGION)..."
	@if [ "$(ENV)" = "nonprod" ]; then \
		cd envs/nonprod && $(TF) plan -var="aws_region=$(REGION)"; \
	elif [ "$(ENV)" = "prod" ]; then \
		cd envs/prod && $(TF) plan -var="aws_region=$(REGION)"; \
	else \
		echo "ERROR: ENV must be 'nonprod' or 'prod'"; \
		exit 1; \
	fi

tf-apply: ## Apply Terraform changes (usage: make tf-apply ENV=nonprod REGION=us-east-1)
	@echo "Applying Terraform changes for $(ENV) in $(REGION)..."
	@if [ "$(ENV)" = "nonprod" ]; then \
		cd envs/nonprod && $(TF) apply -var="aws_region=$(REGION)"; \
	elif [ "$(ENV)" = "prod" ]; then \
		cd envs/prod && $(TF) apply -var="aws_region=$(REGION)"; \
	else \
		echo "ERROR: ENV must be 'nonprod' or 'prod'"; \
		exit 1; \
	fi

tf-destroy: ## Destroy Terraform resources (usage: make tf-destroy ENV=nonprod REGION=us-east-1)
	@echo "WARNING: Destroying Terraform resources for $(ENV) in $(REGION)..."
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@if [ "$(ENV)" = "nonprod" ]; then \
		cd envs/nonprod && $(TF) destroy -var="aws_region=$(REGION)"; \
	elif [ "$(ENV)" = "prod" ]; then \
		cd envs/prod && $(TF) destroy -var="aws_region=$(REGION)"; \
	else \
		echo "ERROR: ENV must be 'nonprod' or 'prod'"; \
		exit 1; \
	fi

###############################################################################
# EKS cluster management via eksctl (new parameterized targets)
###############################################################################
eks-create-env: ## Create EKS cluster for environment (usage: make eks-create-env ENV=nonprod REGION=us-east-1)
	@echo "Creating EKS cluster for $(ENV) in $(REGION)..."
	@if [ "$(ENV)" = "nonprod" ]; then \
		PROFILE=$(DEVQA_PROFILE) eksctl create cluster -f eksctl/devqa-cluster.yaml --region $(REGION); \
	elif [ "$(ENV)" = "prod" ]; then \
		PROFILE=$(PROD_PROFILE) eksctl create cluster -f eksctl/prod-cluster.yaml --region $(REGION); \
	else \
		echo "ERROR: ENV must be 'nonprod' or 'prod'"; \
		exit 1; \
	fi

eks-create: eks-create-env ## Alias for eks-create-env (usage: make eks-create ENV=nonprod REGION=us-east-1)

eks-upgrade: ## Upgrade EKS cluster (usage: make eks-upgrade ENV=nonprod)
	@echo "Upgrading EKS cluster for $(ENV)..."
	@if [ "$(ENV)" = "nonprod" ]; then \
		AWS_PROFILE=$(DEVQA_PROFILE) eksctl upgrade cluster --name $(NONPROD_CLUSTER) --approve; \
	elif [ "$(ENV)" = "prod" ]; then \
		AWS_PROFILE=$(PROD_PROFILE) eksctl upgrade cluster --name $(PROD_CLUSTER) --approve; \
	else \
		echo "ERROR: ENV must be 'nonprod' or 'prod'"; \
		exit 1; \
	fi

eks-delete: ## Delete EKS cluster (usage: make eks-delete ENV=nonprod)
	@echo "WARNING: Deleting EKS cluster for $(ENV)..."
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@if [ "$(ENV)" = "nonprod" ]; then \
		AWS_PROFILE=$(DEVQA_PROFILE) eksctl delete cluster --name $(NONPROD_CLUSTER) --wait; \
	elif [ "$(ENV)" = "prod" ]; then \
		AWS_PROFILE=$(PROD_PROFILE) eksctl delete cluster --name $(PROD_CLUSTER) --wait; \
	else \
		echo "ERROR: ENV must be 'nonprod' or 'prod'"; \
		exit 1; \
	fi

###############################################################################
# Disaster Recovery
###############################################################################
dr-provision-prod: ## Provision prod infrastructure in alternate region (usage: make dr-provision-prod REGION=us-west-2)
	@echo "=========================================="
	@echo "Disaster Recovery: Provisioning prod in $(REGION)"
	@echo "=========================================="
	@echo ""
	@echo "This will:"
	@echo "  1. Login to prod account via SSO"
	@echo "  2. Initialize and apply Terraform in envs/prod"
	@echo "  3. Create EKS cluster using eksctl"
	@echo ""
	@read -p "Continue? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@echo ""
	@echo "Step 1: Logging into prod account..."
	@$(MAKE) login-prod
	@echo ""
	@echo "Step 2: Initializing Terraform..."
	@cd envs/prod && $(TF) init -backend-config=backend.hcl
	@echo ""
	@echo "Step 3: Planning Terraform changes..."
	@cd envs/prod && $(TF) plan -var="aws_region=$(REGION)"
	@echo ""
	@read -p "Apply Terraform changes? (yes/no): " apply && [ "$$apply" = "yes" ] || exit 1
	@echo ""
	@echo "Step 4: Applying Terraform..."
	@cd envs/prod && $(TF) apply -var="aws_region=$(REGION)" -auto-approve
	@echo ""
	@echo "Step 5: Creating EKS cluster..."
	@AWS_PROFILE=$(PROD_PROFILE) eksctl create cluster -f eksctl/prod-cluster.yaml --region $(REGION)
	@echo ""
	@echo "✓ DR provisioning complete for $(REGION)"

###############################################################################
# Output helpers
###############################################################################
outputs: ## Print key infrastructure outputs (usage: make outputs ENV=nonprod)
	@echo "=========================================="
	@echo "Infrastructure Outputs for $(ENV)"
	@echo "=========================================="
	@echo ""
	@if [ "$(ENV)" = "nonprod" ]; then \
		cd envs/nonprod && $(TF) output; \
	elif [ "$(ENV)" = "prod" ]; then \
		cd envs/prod && $(TF) output; \
	else \
		echo "ERROR: ENV must be 'nonprod' or 'prod'"; \
		exit 1; \
	fi

###############################################################################
# EKS cluster creation via eksctl (legacy target for backward compatibility)
###############################################################################
eks-create-legacy: ## Create/upgrade EKS clusters using eksctl (legacy script, requires VPCs exist)
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

###############################################################################
# Disaster Recovery targets
###############################################################################
dr-provision-prod: ## Provision DR resources in prod (usage: make dr-provision-prod REGION=us-west-2)
	@echo "Provisioning DR resources for production in region: $(REGION)"
	@if [ "$(REGION)" = "us-east-1" ]; then \
		echo "ERROR: Cannot use primary region us-east-1 for DR"; \
		exit 1; \
	fi
	cd envs/prod && \
		echo 'enable_ecr_replication = true' > dr-override.auto.tfvars && \
		echo 'ecr_replication_regions = ["$(REGION)"]' >> dr-override.auto.tfvars && \
		echo 'enable_secrets_replication = true' >> dr-override.auto.tfvars && \
		echo 'secrets_replication_regions = ["$(REGION)"]' >> dr-override.auto.tfvars && \
		$(TF) init -backend-config=backend.hcl && \
		$(TF) plan && \
		$(TF) apply -auto-approve

dr-status-prod: ## Show current DR configuration status
	@echo "Checking DR configuration status..."
	cd envs/prod && \
		$(TF) init -backend-config=backend.hcl >/dev/null 2>&1 && \
		$(TF) output -json | grep -E "(ecr_replication|secrets_replication|dns_failover)" || echo "No DR outputs found"

###############################################################################
.PHONY: ops-up ops-open ops-open-skip ops-status ops-down ops-down-full ops-down-qa

# Dev/QA operator helpers
ops-up: ## Scale Dev+QA nodegroups to 1/1/1 and wait for nodes
	PROFILE=$(DEVQA_PROFILE) REGION=$(REGION) CLUSTER=$(NONPROD_CLUSTER) bash scripts/devqa-ops.sh up

ops-open: ## Open local tunnels (Grafana 3000, Prometheus 9090, Argo CD 8080)
	PROFILE=$(DEVQA_PROFILE) REGION=$(REGION) CLUSTER=$(NONPROD_CLUSTER) bash scripts/devqa-ops.sh open

ops-open-skip: ## Open tunnels without refreshing kubeconfig (uses current context)
	SKIP_KUBE_LOGIN=1 PROFILE=$(DEVQA_PROFILE) REGION=$(REGION) CLUSTER=$(NONPROD_CLUSTER) bash scripts/devqa-ops.sh open

ops-status: ## Show nodegroup and node status
	PROFILE=$(DEVQA_PROFILE) REGION=$(REGION) CLUSTER=$(NONPROD_CLUSTER) bash scripts/devqa-ops.sh status

ops-down: ## Graceful shutdown: scale Dev+QA nodegroups to 0/0/1
	PROFILE=$(DEVQA_PROFILE) REGION=$(REGION) CLUSTER=$(NONPROD_CLUSTER) bash scripts/devqa-ops.sh down

ops-down-full: ## Hard shutdown: scale all to 0, remove PDB blockers, drain+terminate leftovers, stop bastion
	PROFILE=$(DEVQA_PROFILE) REGION=$(REGION) CLUSTER=$(NONPROD_CLUSTER) STOP_BASTION=1 bash scripts/devqa-ops.sh down-full

ops-down-qa: ## Scale only QA nodegroup (qa-t3) to 0/0/1 and drain QA nodes
	PROFILE=$(DEVQA_PROFILE) REGION=$(REGION) CLUSTER=$(NONPROD_CLUSTER) bash scripts/devqa-ops.sh down-qa

###############################################################################
.PHONY: ops-verify
ops-verify: ## Verify monitoring and Argo CD are installed and Ready
	PROFILE=$(DEVQA_PROFILE) REGION=$(REGION) CLUSTER=$(NONPROD_CLUSTER) bash -c '\
		aws eks update-kubeconfig --region $$REGION --name $$CLUSTER --profile $$PROFILE >/dev/null || true; \
		bash scripts/ops-verify.sh \
	'