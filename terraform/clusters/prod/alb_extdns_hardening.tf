# Update existing external_dns helm_release for prod to manage internal zone with HA hardening
resource "helm_release" "external_dns_prod_hardened" {
  provider   = helm.prod
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.15.0"

  values = [yamlencode({
    replicaCount = 2
    podDisruptionBudget = {
      minAvailable = 1
    }
    provider = "aws"
    policy   = "upsert-only"
    txtOwnerId = "cb-prod-external-dns"
    domainFilters = [
      "cluckn-bell.com",
      "internal.cluckn-bell.com"
    ]
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
      }
      create = true
      name   = "external-dns"
    }
    
    # Additional hardening
    securityContext = {
      runAsNonRoot = true
      runAsUser    = 65534
      fsGroup      = 65534
    }
    
    resources = {
      limits = {
        cpu    = "100m"
        memory = "128Mi"
      }
      requests = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
    
    # Anti-affinity to spread replicas across nodes
    affinity = {
      podAntiAffinity = {
        preferredDuringSchedulingIgnoredDuringExecution = [
          {
            weight = 100
            podAffinityTerm = {
              labelSelector = {
                matchLabels = {
                  "app.kubernetes.io/name" = "external-dns"
                }
              }
              topologyKey = "kubernetes.io/hostname"
            }
          }
        ]
      }
    }
  })]

  depends_on = [
    module.eks,
    aws_route53_zone.internal_prod
  ]
}

# Update IAM policy to include internal zone
resource "aws_iam_policy" "external_dns_prod_with_internal" {
  provider = aws.prod
  name     = "cb-external-dns-prod-with-internal"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["route53:ChangeResourceRecordSets"],
        Resource = [
          "arn:aws:route53:::hostedzone/${var.prod_apex_zone_id}",
          "arn:aws:route53:::hostedzone/${aws_route53_zone.internal_prod.zone_id}"
        ]
      },
      {
        Effect   = "Allow",
        Action   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:GetHostedZone"],
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns_attach_prod_with_internal" {
  provider   = aws.prod
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns_prod_with_internal.arn
}