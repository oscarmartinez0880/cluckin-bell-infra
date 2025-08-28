# ECR Repository Management

This document outlines the ECR repositories to be created in each AWS account for the Cluckin' Bell infrastructure, along with required configurations and best practices.

## Repository List

The following ECR repositories should be created in both the QA/Dev account (264765154707) and Production account (346746763840):

### Core Application Repositories

| Repository Name | Purpose | Description |
|----------------|---------|-------------|
| `cluckin-bell-app` | Main Application | Primary web application container |
| `wingman-api` | API Service | Backend API service container |

## Image Tagging Strategy

### Environment-Specific Tagging Standards

To ensure consistent deployments across environments while preventing the use of `:latest` tags outside production, the following tagging strategy is implemented:

| Environment | ECR Account | Repository Base | Image Tag | Example |
|-------------|-------------|-----------------|-----------|---------|
| Development | 264765154707 | `264765154707.dkr.ecr.us-east-1.amazonaws.com/` | `dev` | `264765154707.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:dev` |
| QA | 264765154707 | `264765154707.dkr.ecr.us-east-1.amazonaws.com/` | `qa` | `264765154707.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:qa` |
| Production | 346746763840 | `346746763840.dkr.ecr.us-east-1.amazonaws.com/` | `prod` | `346746763840.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:prod` |

### Secondary Tagging
- **SHA Tags**: All environments also push `sha-{git-sha}` tags for traceability
- **Latest Tag**: Only production pushes `latest` tag (in addition to `prod`)
- **No `:latest` outside prod**: Development and QA environments must not use `:latest` tags

### Repository Account Separation
- **Nonprod Account (264765154707)**: Serves both dev and qa environments, sharing the same ECR repositories but with different tags
- **Prod Account (346746763840)**: Dedicated for production with separate ECR repositories for security isolation

## Required Configuration

Each ECR repository must be configured with the following settings:

### Image Tag Immutability
- **Setting**: `IMMUTABLE`
- **Reason**: Prevents accidental overwriting of image tags, ensuring deployment consistency

### Enhanced Image Scanning
- **Setting**: `ENABLED` (scan on push)
- **Reason**: Automatically scans for security vulnerabilities on image push

### Encryption
- **Setting**: AES256 or KMS encryption
- **Reason**: Ensures container images are encrypted at rest

### Lifecycle Policy
- **Untagged Images**: Retain for 1 day
- **Tagged Images**: Keep last 50 images with environment tags (`dev`, `qa`, `prod`, `sha-`)
- **All Images**: Maximum 100 images total

## Terraform Module Example

### Nonprod Account (264765154707)
```hcl
module "ecr_repositories" {
  source = "./modules/ecr"

  repository_names = [
    "cluckin-bell-app",
    "wingman-api"
  ]

  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
  enable_lifecycle_policy = true
  max_image_count      = 50
  untagged_image_days  = 1

  tags = {
    Project     = "cluckin-bell"
    Environment = "nonprod"
    Account     = "264765154707"
  }
}
```

### Prod Account (346746763840)
```hcl
module "ecr_repositories" {
  source = "./modules/ecr"

  repository_names = [
    "cluckin-bell-app",
    "wingman-api"
  ]

  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
  enable_lifecycle_policy = true
  max_image_count      = 50
  untagged_image_days  = 1

  tags = {
    Project     = "cluckin-bell"
    Environment = "prod"
    Account     = "346746763840"
    ManagedBy = "terraform"
  }
}
```

## Cross-Account Access

For CI/CD workflows that need to push images from one account to another, configure cross-account access policies. See `docs/irsa-ecr-policy.json` for the minimal required permissions.

## Lifecycle Policy Details

The following lifecycle policy should be applied to all repositories:

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 30 tagged images with v prefix",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Delete untagged images older than 1 day",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
      "description": "Keep maximum 100 images total",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan", 
        "countNumber": 100
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

## Security Scanning

Enable Amazon ECR enhanced scanning (formerly Inspector) for:
- **Vulnerability scanning**: Continuous monitoring for CVEs
- **OS package scanning**: Detection of vulnerable OS packages  
- **Programming language scanning**: Scanning of application dependencies

## Monitoring and Alerts

Set up CloudWatch alarms for:
- Repository size growth
- Image push failures
- High severity vulnerabilities detected
- Lifecycle policy execution

## Access Patterns

### Development/QA Account (264765154707)
- Used for dev and qa environment deployments
- CI/CD pipelines push images here for testing
- Cross-account pull access to production account

### Production Account (346746763840)  
- Used exclusively for production deployments
- Images promoted from dev/qa account
- Stricter access controls and monitoring