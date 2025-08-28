# ALB Controller: pin chart version, set replicas and PDB via helm values
module "aws_load_balancer_controller" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-load-balancer-controller"
  version = "~> 20.8"
  providers = { aws = aws.prod }

  cluster_name              = module.eks.cluster_name
  cluster_oidc_provider_arn = module.eks.oidc_provider_arn
  create_policy             = true

  helm_chart_version = "1.8.1"
  values = [yamlencode({
    replicaCount = 2,
    podDisruptionBudget = { minAvailable = 1 }
  })]
}

# ExternalDNS: add HA and PDB; retains prior domainFilters and IRSA
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.15.0"

  values = [yamlencode({
    replicaCount    = 2,
    podDisruptionBudget = { minAvailable = 1 },
    provider      = "aws",
    policy        = "upsert-only",
    txtOwnerId    = "cb-prod-external-dns",
    domainFilters = ["cluckn-bell.com"],
    serviceAccount = {
      annotations = { "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn },
      create      = true,
      name        = "external-dns"
    }
  })]
}