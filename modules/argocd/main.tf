terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# ArgoCD Helm release
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version

  values = [
    yamlencode({
      global = {
        image = {
          tag = var.argocd_version
        }
      }

      configs = {
        params = {
          "server.insecure" = true
        }
        secret = {
          # Enable admin user for authentication
          argocdServerAdminPassword      = "$2a$10$rRyBsGSHK6.uc8fntPwVIeWd9tOtqBvBZ7P9uKzYiwtQkuWPvEFeO" # Default: admin
          argocdServerAdminPasswordMtime = "2023-01-01T00:00:00Z"
        }
        cm = {
          # Enable admin user
          "admin.enabled" = true
          # Disable anonymous access
          "users.anonymous.enabled" = false
        }
      }

      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internal" # Internal ALB
          }
        }
        ingress = {
          enabled = false
        }
      }

      dex = {
        enabled = false
      }

      notifications = {
        enabled = false
      }

      applicationSet = {
        enabled = true
      }
    })
  ]

  depends_on = [var.node_groups]
}

# Wait for ArgoCD to be ready
resource "kubernetes_manifest" "wait_for_argocd" {
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "argocd-ready"
      namespace = var.namespace
    }
    data = {
      ready = "true"
    }
  }

  depends_on = [helm_release.argocd]
}

# ArgoCD Application for the main cluckin-bell app
resource "kubernetes_manifest" "cluckin_bell_application" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "cluckin-bell-${var.environment}"
      namespace = var.namespace
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repository
        targetRevision = var.git_revision
        path           = var.git_path
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [kubernetes_manifest.wait_for_argocd]
}

# Get ArgoCD server service to retrieve LoadBalancer endpoint
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = var.namespace
  }

  depends_on = [helm_release.argocd]
}