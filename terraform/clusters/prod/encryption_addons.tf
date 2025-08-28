# KMS key for EKS secrets encryption
resource "aws_kms_key" "eks_secrets" {
  provider                = aws.prod
  description             = "EKS secrets envelope encryption (prod)"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "eks_secrets" {
  provider = aws.prod
  name     = "alias/cb-prod-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# Managed add-ons
resource "aws_eks_addon" "vpc_cni" {
  provider            = aws.prod
  cluster_name        = module.eks.cluster_name
  addon_name          = "vpc-cni"
  resolve_conflicts_on_update = "PRESERVE"
}

resource "aws_eks_addon" "coredns" {
  provider            = aws.prod
  cluster_name        = module.eks.cluster_name
  addon_name          = "coredns"
  resolve_conflicts_on_update = "PRESERVE"
}

resource "aws_eks_addon" "kube_proxy" {
  provider            = aws.prod
  cluster_name        = module.eks.cluster_name
  addon_name          = "kube-proxy"
  resolve_conflicts_on_update = "PRESERVE"
}

# EBS CSI driver requires IAM policy; create IRSA role and attach policy
data "aws_iam_policy_document" "ebs_csi_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals { type = "Federated", identifiers = [module.eks.oidc_provider_arn] }
    condition {
      test     = "StringEquals"
      variable = replace(module.eks.cluster_oidc_issuer_url, "https://", "") + ":sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  provider           = aws.prod
  name               = "cb-prod-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi_attach" {
  provider  = aws.prod
  role      = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  provider            = aws.prod
  cluster_name        = module.eks.cluster_name
  addon_name          = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_update = "PRESERVE"
}

variable "api_public_cidrs" { 
  description = "List of CIDR blocks for public access to the EKS cluster endpoint"
  type = list(string) 
  default = [] 
}