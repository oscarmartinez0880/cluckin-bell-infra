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

# AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  namespace  = var.namespace == "kube-system" ? "kube-system" : var.namespace
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_version

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.aws_load_balancer_controller_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [var.node_groups]
}

# cert-manager
resource "kubernetes_namespace" "cert_manager" {
  count = var.enable_cert_manager && var.namespace != "kube-system" ? 1 : 0

  metadata {
    name = var.namespace
    labels = {
      "cert-manager.io/disable-validation" = "true"
    }
  }
}

resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name       = "cert-manager"
  namespace  = var.namespace
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "cert-manager"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cert_manager_role_arn
  }

  depends_on = [var.node_groups]
}

# ClusterIssuer for Let's Encrypt staging
resource "kubernetes_manifest" "cluster_issuer_staging" {
  count = var.enable_cert_manager ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-staging"
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-staging"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region = var.aws_region
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# ClusterIssuer for Let's Encrypt production
resource "kubernetes_manifest" "cluster_issuer_prod" {
  count = var.enable_cert_manager ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region = var.aws_region
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# external-dns
resource "helm_release" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name       = "external-dns"
  namespace  = var.namespace == "kube-system" ? "kube-system" : var.namespace
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_version

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "aws.region"
    value = var.aws_region
  }

  set {
    name  = "domainFilters[0]"
    value = var.domain_filter
  }

  # Zone ID filters for managing both public and private zones
  dynamic "set" {
    for_each = var.zone_id_filters
    content {
      name  = "zoneIdFilters[${set.key}]"
      value = set.value
    }
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.external_dns_role_arn
  }

  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }

  depends_on = [var.node_groups]
}

# Create namespace for Argo CD
resource "kubernetes_namespace" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = "argocd"
    labels = {
      "app.kubernetes.io/name" = "argocd"
    }
  }
}

# Create secret for CodeCommit repository if provided
resource "kubernetes_secret" "argocd_codecommit_repo" {
  count = var.enable_argocd && var.codecommit_repository_url != "" ? 1 : 0

  metadata {
    name      = "codecommit-repo"
    namespace = kubernetes_namespace.argocd[0].metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type = "git"
    url  = var.codecommit_repository_url
    name = "cluckn-bell"
  }
}

# Argo CD Helm release
resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd"
  namespace  = kubernetes_namespace.argocd[0].metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version

  values = [
    yamlencode(merge({
      global = {
        domain = "argocd.${var.environment == "prod" ? "cluckn-bell.com" : "${var.environment}.cluckn-bell.com"}"
      }
      
      configs = {
        params = {
          "server.insecure" = true  # We'll use TLS termination at ALB
        }
        repositories = var.codecommit_repository_url != "" ? {
          "codecommit::${var.aws_region}://cluckin-bell" = {
            url  = var.codecommit_repository_url
            name = "cluckn-bell"
          }
        } : {}
      }
      
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled = true
          ingressClassName = "alb"
          annotations = {
            "alb.ingress.kubernetes.io/scheme" = "internal"
            "alb.ingress.kubernetes.io/target-type" = "ip"
            "alb.ingress.kubernetes.io/group.name" = "argocd"
            "alb.ingress.kubernetes.io/ssl-redirect" = "443"
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
          }
          hosts = [
            "argocd.${var.environment == "prod" ? "cluckn-bell.com" : "${var.environment}.cluckn-bell.com"}"
          ]
          paths = [
            "/"
          ]
          pathType = "Prefix"
          tls = [
            {
              secretName = "argocd-server-tls"
              hosts = [
                "argocd.${var.environment == "prod" ? "cluckn-bell.com" : "${var.environment}.cluckn-bell.com"}"
              ]
            }
          ]
        }
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
            value = var.aws_region
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

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.aws_load_balancer_controller
  ]
}