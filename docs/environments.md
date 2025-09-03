# Environment Management

## Overview

This repository manages infrastructure across multiple environments using a one-tfvars-per-root approach. Each environment has its own dedicated Terraform root with a single tfvars file containing all configuration values.

## Environment Structure

### Available Environments

- **envs/nonprod**: Shared development and QA environment
- **envs/prod**: Production environment

### One-tfvars-per-root Approach

Each environment root contains:
- `main.tf`: Infrastructure module declarations
- `variables.tf`: Variable definitions for the root
- `providers.tf`: Provider configurations
- `outputs.tf`: Output definitions
- `{env}.tfvars`: Single configuration file with all values

This approach provides:
- Clear separation between environments
- Simplified configuration management
- Reduced risk of cross-environment contamination
- Easy to understand and maintain

## Canonical Commands

### Non-Production Environment

Initialize and upgrade providers:
```bash
terraform -chdir=envs/nonprod init -upgrade
```

Plan infrastructure changes:
```bash
terraform -chdir=envs/nonprod plan -var-file=nonprod.tfvars
```

Apply infrastructure changes:
```bash
terraform -chdir=envs/nonprod apply -var-file=nonprod.tfvars
```

### Production Environment

Initialize and upgrade providers:
```bash
terraform -chdir=envs/prod init -upgrade
```

Plan infrastructure changes:
```bash
terraform -chdir=envs/prod plan -var-file=prod.tfvars
```

Apply infrastructure changes:
```bash
terraform -chdir=envs/prod apply -var-file=prod.tfvars
```

## Configuration Guidelines

### Root Variables vs Module Variables

- **Root tfvars files** should only contain variables declared in the root's `variables.tf`
- **Module-specific configurations** (like `public_zone`, `private_zone`) belong directly in module blocks within `main.tf`
- This separation ensures clear boundaries and prevents variable declaration errors

### DNS and Certificate Management

The infrastructure uses a shared DNS pattern:
- **dev environment**: Creates a private zone for internal services
- **qa environment**: Reuses the private zone from dev using `existing_private_zone_id`
- This prevents hosted zone lookup races and ensures consistent DNS resolution

### Provider Management

Each environment includes explicit provider requirements:
- Helm provider for Kubernetes package management
- Kubernetes provider for direct API interaction
- AWS provider for cloud resource management

All providers use `v1` API version for stability and compatibility.

## Best Practices

1. **Always use the canonical commands** with explicit `-chdir` and `-var-file` parameters
2. **Review plans carefully** before applying, especially in production
3. **Test changes in nonprod** before promoting to production
4. **Use consistent tagging** across all resources for better organization
5. **Follow the principle of least privilege** for IAM roles and policies

## Troubleshooting

### Common Issues

- **Provider schema warnings**: Run `terraform init -upgrade` to update provider schemas
- **Undeclared variable warnings**: Ensure all variables in tfvars are declared in `variables.tf`
- **Zone lookup races**: Use `existing_private_zone_id` for zone reuse instead of name-based lookups

### Validation

Before making changes, always validate:
1. Terraform initialization completes without errors
2. Plan shows expected changes without warnings
3. All required providers are recognized
4. No data source indexing errors occur