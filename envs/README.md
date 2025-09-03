# Environment Configuration

This directory contains environment-specific Terraform configurations for the Cluckin' Bell infrastructure.

## Structure

- `nonprod/` - Development and QA environment (shared cluster in account 264765154707)
- `prod/` - Production environment (dedicated cluster in account 346746763840)

## Variable Files

Each environment has a single, comprehensive `.tfvars` file:

- `nonprod/devqa.tfvars` - All configuration for the nonprod environment
- `prod/prod.tfvars` - All configuration for the production environment

## Usage

### Deploy Nonprod Environment
```bash
cd envs/nonprod
terraform init
terraform plan -var-file=devqa.tfvars
terraform apply -var-file=devqa.tfvars
```

### Deploy Prod Environment
```bash
cd envs/prod
terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars
```

## Key Variables

### Nonprod Environment
- Single shared EKS cluster for dev and qa workloads
- Route53 zones: `dev.cluckn-bell.com`, `qa.cluckn-bell.com`
- Private zone: `cluckn-bell.com` (shared)

### Prod Environment
- Dedicated EKS cluster for production workloads
- Route53 zones: `cluckn-bell.com` (root domain)
- NS delegations for dev/qa subdomains from nonprod account

## Name Server Configuration

The production environment requires name servers from the nonprod environment for subdomain delegation:

1. Deploy nonprod environment first
2. Get name servers: `terraform output dev_zone_name_servers qa_zone_name_servers`
3. Update `prod.tfvars` with the actual name server values
4. Deploy production environment

## DNS Module Changes

The DNS module now supports both:
- Creating new Route53 zones
- Referencing existing zones by ID (to avoid race conditions)

This eliminates the previous race condition where the QA module would try to lookup the private zone before the dev module had created it.