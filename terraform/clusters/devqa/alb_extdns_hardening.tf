# Update existing external_dns helm_release to manage internal zone too with HA hardening
resource "helm_release" "external_dns_devqa_hardened" {
  provider   = helm.devqa
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
    txtOwnerId = "cb-devqa-external-dns"
    domainFilters = [
      "dev.cluckn-bell.com",
      "qa.cluckn-bell.com",
      "internal.dev.cluckn-bell.com"
    ]
    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns_devqa.arn
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
    module.eks_devqa,
    aws_route53_zone.internal_dev
  ]
}

# Update IAM policy to include internal zone
resource "aws_iam_policy" "external_dns_devqa_with_internal" {
  provider = aws.devqa
  name     = "cb-external-dns-devqa-with-internal"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["route53:ChangeResourceRecordSets"],
        Resource = [
          "arn:aws:route53:::hostedzone/${var.dev_zone_id}",
          "arn:aws:route53:::hostedzone/${var.qa_zone_id}",
          "arn:aws:route53:::hostedzone/${aws_route53_zone.internal_dev.zone_id}"
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

resource "aws_iam_role_policy_attachment" "external_dns_attach_devqa_with_internal" {
  provider   = aws.devqa
  role       = aws_iam_role.external_dns_devqa.name
  policy_arn = aws_iam_policy.external_dns_devqa_with_internal.arn
}