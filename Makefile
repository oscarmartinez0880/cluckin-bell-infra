# Global defaults
ENV ?= nonprod          # nonprod|prod
REGION ?= us-east-1
TF_VERSION := 1.13.1
EKSCTL := eksctl

# Profile names must match your ~/.aws/config
NONPROD_PROFILE := cluckin-bell-qa
PROD_PROFILE    := cluckin-bell-prod

# Paths
TF_DIR_NONPROD := envs/nonprod
TF_DIR_PROD    := envs/prod
EKSCTL_CFG_NONPROD := eksctl/devqa-cluster.yaml
EKSCTL_CFG_PROD    := eksctl/prod-cluster.yaml

# Select dirs based on ENV (only validate when needed)
ifeq ($(ENV),nonprod)
  TF_DIR := $(TF_DIR_NONPROD)
  AWS_PROFILE := $(NONPROD_PROFILE)
  EKSCTL_CFG := $(EKSCTL_CFG_NONPROD)
else ifeq ($(ENV),prod)
  TF_DIR := $(TF_DIR_PROD)
  AWS_PROFILE := $(PROD_PROFILE)
  EKSCTL_CFG := $(EKSCTL_CFG_PROD)
endif

.PHONY: help
help:
	@echo "Targets:"
	@echo "  login-nonprod / login-prod     - AWS SSO login for the account"
	@echo "  tf-init|tf-plan|tf-apply|tf-destroy ENV=nonprod|prod REGION=us-east-1"
	@echo "  eks-create|eks-upgrade|eks-delete ENV=nonprod|prod REGION=us-east-1"
	@echo "  outputs ENV=nonprod|prod       - Show key Terraform outputs"
	@echo "  dr-provision-prod REGION=us-west-2 - Provision prod infra + EKS in new region"
	@echo "Variables: ENV, REGION"

# SSO logins
.PHONY: login-nonprod login-prod
login-nonprod:
	aws sso login --profile $(NONPROD_PROFILE)
login-prod:
	aws sso login --profile $(PROD_PROFILE)

# Terraform wrappers
.PHONY: tf-init tf-plan tf-apply tf-destroy
tf-init:
	@if [ "$(ENV)" != "nonprod" ] && [ "$(ENV)" != "prod" ]; then echo "ERROR: ENV must be nonprod or prod"; exit 1; fi
	@echo "==> Terraform init in $(TF_DIR) (region=$(REGION), env=$(ENV))"
	cd $(TF_DIR) && AWS_PROFILE=$(AWS_PROFILE) terraform init -upgrade

tf-plan:
	@if [ "$(ENV)" != "nonprod" ] && [ "$(ENV)" != "prod" ]; then echo "ERROR: ENV must be nonprod or prod"; exit 1; fi
	@echo "==> Terraform plan in $(TF_DIR) (region=$(REGION), env=$(ENV))"
	cd $(TF_DIR) && AWS_PROFILE=$(AWS_PROFILE) terraform validate && terraform fmt -recursive && terraform plan -var="aws_region=$(REGION)"

tf-apply:
	@if [ "$(ENV)" != "nonprod" ] && [ "$(ENV)" != "prod" ]; then echo "ERROR: ENV must be nonprod or prod"; exit 1; fi
	@echo "==> Terraform apply in $(TF_DIR) (region=$(REGION), env=$(ENV))"
	cd $(TF_DIR) && AWS_PROFILE=$(AWS_PROFILE) terraform apply -auto-approve -var="aws_region=$(REGION)"

tf-destroy:
	@if [ "$(ENV)" != "nonprod" ] && [ "$(ENV)" != "prod" ]; then echo "ERROR: ENV must be nonprod or prod"; exit 1; fi
	@echo "==> Terraform destroy in $(TF_DIR) (region=$(REGION), env=$(ENV))"
	cd $(TF_DIR) && AWS_PROFILE=$(AWS_PROFILE) terraform destroy -auto-approve -var="aws_region=$(REGION)"

# eksctl wrappers (cluster lifecycle)
.PHONY: eks-create eks-upgrade eks-delete
eks-create:
	@if [ "$(ENV)" != "nonprod" ] && [ "$(ENV)" != "prod" ]; then echo "ERROR: ENV must be nonprod or prod"; exit 1; fi
	@echo "==> Creating EKS cluster (env=$(ENV), region=$(REGION))"
	AWS_PROFILE=$(AWS_PROFILE) $(EKSCTL) create cluster --config-file=$(EKSCTL_CFG) --region $(REGION)

eks-upgrade:
	@if [ "$(ENV)" != "nonprod" ] && [ "$(ENV)" != "prod" ]; then echo "ERROR: ENV must be nonprod or prod"; exit 1; fi
	@echo "==> Upgrading EKS cluster (env=$(ENV), region=$(REGION))"
	AWS_PROFILE=$(AWS_PROFILE) $(EKSCTL) upgrade cluster --config-file=$(EKSCTL_CFG) --region $(REGION) --approve

eks-delete:
	@if [ "$(ENV)" != "nonprod" ] && [ "$(ENV)" != "prod" ]; then echo "ERROR: ENV must be nonprod or prod"; exit 1; fi
	@echo "==> Deleting EKS cluster (env=$(ENV), region=$(REGION))"
	AWS_PROFILE=$(AWS_PROFILE) $(EKSCTL) delete cluster --config-file=$(EKSCTL_CFG) --region $(REGION)

# Outputs shortcut
.PHONY: outputs
outputs:
	@if [ "$(ENV)" != "nonprod" ] && [ "$(ENV)" != "prod" ]; then echo "ERROR: ENV must be nonprod or prod"; exit 1; fi
	@echo "==> Terraform outputs (env=$(ENV))"
	cd $(TF_DIR) && AWS_PROFILE=$(AWS_PROFILE) terraform output

# DR: minimal commands to stand up prod in another region
# - Provisions VPC, RDS, ECR, Route53 links (where applicable) via Terraform
# - Creates EKS in target region via eksctl
.PHONY: dr-provision-prod
dr-provision-prod:
	@[ -n "$(REGION)" ] || (echo "Set REGION for DR (e.g., us-west-2)"; exit 1)
	@echo "==> DR provisioning: prod in $(REGION)"
	$(MAKE) login-prod
	@echo "==> Terraform apply (prod) in new region"
	cd $(TF_DIR_PROD) && AWS_PROFILE=$(PROD_PROFILE) terraform apply -auto-approve -var="aws_region=$(REGION)"
	@echo "==> Create EKS cluster (prod) in new region"
	AWS_PROFILE=$(PROD_PROFILE) $(EKSCTL) create cluster --config-file=$(EKSCTL_CFG_PROD) --region $(REGION)
	@echo "==> DR provisioning complete for prod in $(REGION)"

###############################################################################
# Legacy targets (preserved for backward compatibility)
###############################################################################
.PHONY: check-tools
.PHONY: sso-devqa sso-prod
.PHONY: accounts-devqa accounts-prod dns vpc
.PHONY: iam-nonprod iam-prod
.PHONY: infra-nonprod infra-prod
.PHONY: eks-create-legacy
.PHONY: irsa-nonprod irsa-prod irsa-bootstrap
.PHONY: outputs-vpc
.PHONY: init fmt fmt-check validate plan plan-out apply apply-auto apply-plan destroy clean show refresh
.PHONY: workspace-list workspace-new workspace-select lint ci
.PHONY: test-ecr-dry test-ecr-dev test-ecr-qa test-ecr-prod test-ecr-all test-ecr-status test-ecr-collect test-ecr-help

TF ?= terraform
NONPROD_CLUSTER ?= cluckn-bell-nonprod
PROD_CLUSTER ?= cluckn-bell-prod
DEVQA_PROFILE ?= cluckin-bell-qa

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
# AWS SSO Login (legacy aliases)
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
# EKS cluster creation via eksctl (legacy)
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