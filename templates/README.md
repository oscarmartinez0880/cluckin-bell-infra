# Kubernetes Application Deployment Templates

This directory contains standardized Helm charts and Kustomize overlays for deploying Cluckin' Bell applications with environment-specific configurations.

## Overview

The templates implement the following environment-specific image tagging and repository strategy:

### Image Repositories by Environment

| Environment | Account ID | Repository Base | Example |
|-------------|------------|-----------------|---------|
| Development | 264765154707 | `264765154707.dkr.ecr.us-east-1.amazonaws.com/` | `264765154707.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:dev` |
| QA | 264765154707 | `264765154707.dkr.ecr.us-east-1.amazonaws.com/` | `264765154707.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:qa` |
| Production | 346746763840 | `346746763840.dkr.ecr.us-east-1.amazonaws.com/` | `346746763840.dkr.ecr.us-east-1.amazonaws.com/cluckin-bell-app:prod` |

### Image Tagging Strategy

- **Dev**: Uses `dev` tag
- **QA**: Uses `qa` tag  
- **Prod**: Uses `prod` tag (and optionally `latest`)
- **No `:latest` tags** outside of production environment

## Directory Structure

```
templates/
├── helm/
│   ├── cluckin-bell-app/          # Main application Helm chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml            # Default values
│   │   ├── values.dev.yaml        # Development overrides
│   │   ├── values.qa.yaml         # QA overrides
│   │   ├── values.prod.yaml       # Production overrides
│   │   └── templates/             # Kubernetes manifests
│   └── wingman-api/               # API service Helm chart
│       ├── Chart.yaml
│       ├── values.yaml            # Default values
│       ├── values.dev.yaml        # Development overrides
│       ├── values.qa.yaml         # QA overrides
│       ├── values.prod.yaml       # Production overrides
│       └── templates/             # Kubernetes manifests
└── kustomize/
    ├── cluckin-bell-app/
    │   ├── base/                  # Base manifests
    │   └── overlays/
    │       ├── dev/               # Development patches
    │       ├── qa/                # QA patches
    │       └── prod/              # Production patches
    └── wingman-api/
        ├── base/                  # Base manifests
        └── overlays/
            ├── dev/               # Development patches
            ├── qa/                # QA patches
            └── prod/              # Production patches
```

## Usage

### Using Helm Charts

#### Deploy to Development
```bash
helm upgrade --install cluckin-bell-app ./templates/helm/cluckin-bell-app \
  --namespace cluckin-bell \
  --values ./templates/helm/cluckin-bell-app/values.dev.yaml
```

#### Deploy to QA
```bash
helm upgrade --install cluckin-bell-app ./templates/helm/cluckin-bell-app \
  --namespace cluckin-bell \
  --values ./templates/helm/cluckin-bell-app/values.qa.yaml
```

#### Deploy to Production
```bash
helm upgrade --install cluckin-bell-app ./templates/helm/cluckin-bell-app \
  --namespace cluckin-bell \
  --values ./templates/helm/cluckin-bell-app/values.prod.yaml
```

### Using Kustomize

#### Deploy to Development
```bash
kubectl apply -k ./templates/kustomize/cluckin-bell-app/overlays/dev
```

#### Deploy to QA
```bash
kubectl apply -k ./templates/kustomize/cluckin-bell-app/overlays/qa
```

#### Deploy to Production
```bash
kubectl apply -k ./templates/kustomize/cluckin-bell-app/overlays/prod
```

## Environment-Specific Configurations

### Development Environment
- **Image Repository**: `264765154707.dkr.ecr.us-east-1.amazonaws.com/`
- **Image Tag**: `dev`
- **Domain**: `dev.cluckn-bell.com` (frontend), `api.dev.cluckn-bell.com` (API)
- **Replicas**: 1 (apps), 1 (api)
- **Resources**: Minimal for cost optimization
- **Log Level**: `debug`

### QA Environment  
- **Image Repository**: `264765154707.dkr.ecr.us-east-1.amazonaws.com/`
- **Image Tag**: `qa`
- **Domain**: `qa.cluckn-bell.com` (frontend), `api.qa.cluckn-bell.com` (API)
- **Replicas**: 2 (apps), 2 (api)
- **Resources**: Moderate for testing
- **Log Level**: `info`

### Production Environment
- **Image Repository**: `346746763840.dkr.ecr.us-east-1.amazonaws.com/`
- **Image Tag**: `prod`
- **Domain**: `cluckn-bell.com` (frontend), `api.cluckn-bell.com` (API)
- **Replicas**: 3+ with HPA enabled
- **Resources**: Optimized for performance
- **Log Level**: `warn`
- **Auto-scaling**: Enabled (min: 3, max: 10, target: 70% CPU)

## Application Repository Structure

These templates should be used within the application repository (`oscarmartinez0880/cluckin-bell`) with the following structure:

```
oscarmartinez0880/cluckin-bell/
├── k8s/
│   ├── dev/                       # ArgoCD syncs from this path for dev
│   │   ├── cluckin-bell-app/
│   │   └── wingman-api/
│   ├── qa/                        # ArgoCD syncs from this path for qa
│   │   ├── cluckin-bell-app/
│   │   └── wingman-api/
│   └── prod/                      # ArgoCD syncs from this path for prod
│       ├── cluckin-bell-app/
│       └── wingman-api/
└── ...
```

## GitOps Integration

ArgoCD is configured to sync applications from the GitHub repository:
- **Repository**: `https://github.com/oscarmartinez0880/cluckin-bell.git`
- **Dev Path**: `k8s/dev`
- **QA Path**: `k8s/qa`  
- **Prod Path**: `k8s/prod`

The applications will be automatically deployed to the `cluckin-bell` namespace in each respective EKS cluster.

## Security and Best Practices

1. **Image Immutability**: ECR repositories are configured with immutable tags
2. **Security Scanning**: Enhanced image scanning enabled on all ECR repositories
3. **Resource Limits**: All deployments include resource requests and limits
4. **Health Checks**: Liveness and readiness probes configured
5. **TLS Termination**: Automatic HTTPS with Let's Encrypt certificates
6. **DNS Management**: Automatic DNS record creation with external-dns

## Customization

To customize these templates for your specific needs:

1. **Copy** the relevant templates to your application repository
2. **Modify** the values files or kustomization patches as needed
3. **Update** image references to match your ECR repositories
4. **Adjust** resource requirements based on your application needs
5. **Configure** environment-specific variables in the values files or patches

## Troubleshooting

### Common Issues

1. **Image Pull Errors**: Ensure ECR repository exists and image tag is pushed
2. **DNS Resolution**: Verify external-dns is running and Route53 hosted zone exists
3. **Certificate Issues**: Check cert-manager logs and cluster-issuer status
4. **Resource Constraints**: Monitor node resources and adjust requests/limits

### Validation Commands

```bash
# Validate Helm charts
helm lint ./templates/helm/cluckin-bell-app
helm template test ./templates/helm/cluckin-bell-app --values ./templates/helm/cluckin-bell-app/values.dev.yaml

# Validate Kustomize overlays
kustomize build ./templates/kustomize/cluckin-bell-app/overlays/dev
kubectl apply --dry-run=client -k ./templates/kustomize/cluckin-bell-app/overlays/dev
```