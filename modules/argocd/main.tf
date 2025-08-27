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

# ArgoCD Helm release
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version

  values = [
    yamlencode(merge({
      global = {
        image = {
          tag = var.argocd_version
        }
      }
      
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      
      server = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
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
    },
    var.argocd_repo_server_role_arn != "" ? {
      repoServer = {
        serviceAccount = {
          create = true
          name   = "argocd-repo-server"
          annotations = {
            "eks.amazonaws.com/role-arn" = var.argocd_repo_server_role_arn
          }
        }
        env = [
          {
            name  = "AWS_REGION"
            value = "us-east-1"
          },
          {
            name  = "PATH"
            value = "/custom-tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
          }
        ]
        initContainers = [
          {
            name  = "install-git-remote-codecommit"
            image = "python:3.9-alpine"
            command = ["/bin/sh", "-c"]
            args = [
              "pip install git-remote-codecommit && cp -r /usr/local/lib/python3.9/site-packages/git_remote_codecommit /custom-tools/ && cp /usr/local/bin/git-remote-codecommit /custom-tools/"
            ]
            volumeMounts = [
              {
                name      = "custom-tools"
                mountPath = "/custom-tools"
              }
            ]
          }
        ]
        volumes = [
          {
            name = "custom-tools"
            emptyDir = {}
          }
        ]
        volumeMounts = [
          {
            name      = "custom-tools"
            mountPath = "/custom-tools"
          }
        ]
      }
    } : {}))
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