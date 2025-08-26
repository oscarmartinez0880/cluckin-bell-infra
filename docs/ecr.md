# ECR Repository Management

This document outlines the ECR repositories to be created in each AWS account for the Cluckin' Bell infrastructure, along with required configurations and best practices.

## Repository List

The following ECR repositories should be created in both the QA/Dev account (264765154707) and Production account (346746763840):

### Core Application Repositories

| Repository Name | Purpose | Description |
|----------------|---------|-------------|
| `cluckin-bell-app` | Main Application | Primary web application container |
| `wingman-api` | API Service | Backend API service container |
| `fryer-worker` | Background Worker | Asynchronous job processing container |
| `sauce-gateway` | Gateway/Proxy | API gateway and routing container |
| `clucker-notify` | Notifications | Notification service container |

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
- **Tagged Images**: Keep last 30 images with "v" prefix
- **All Images**: Maximum 100 images total

## Terraform Module Example

```hcl
module "ecr_repositories" {
  source = "./modules/ecr"

  repository_names = [
    "cluckin-bell-app",
    "wingman-api", 
    "fryer-worker",
    "sauce-gateway",
    "clucker-notify"
  ]

  image_tag_mutability = "IMMUTABLE"
  scan_on_push         = true
  enable_lifecycle_policy = true
  max_image_count      = 100
  untagged_image_days  = 1

  tags = {
    Project   = "cluckin-bell"
    Env       = var.environment
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