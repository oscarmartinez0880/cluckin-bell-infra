# NGINX Ingress Controller via Helm
# Requires helm and kubernetes providers configured for the target EKS cluster
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  namespace  = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.2"

  create_namespace = true

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
  }

  set {
    name  = "controller.ingressClass"
    value = "nginx"
  }

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  # optional: make this the default ingress class
  set {
    name  = "controller.ingressClassResource.default"
    value = "true"
  }
}