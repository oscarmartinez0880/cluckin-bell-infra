# EKS Cluster Service Role
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# EKS Node Group Service Role
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# IRSA for VPC CNI
resource "aws_iam_role" "vpc_cni" {
  name = "${var.cluster_name}-vpc-cni-role"

  assume_role_policy = templatefile("${path.module}/templates/irsa-trust-policy.json", {
    oidc_arn        = aws_iam_openid_connect_provider.cluster.arn
    oidc_url        = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")
    namespace       = "kube-system"
    service_account = "aws-node"
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# IRSA for EBS CSI Driver
resource "aws_iam_role" "ebs_csi" {
  name = "${var.cluster_name}-ebs-csi-role"

  assume_role_policy = templatefile("${path.module}/templates/irsa-trust-policy.json", {
    oidc_arn        = aws_iam_openid_connect_provider.cluster.arn
    oidc_url        = replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")
    namespace       = "kube-system"
    service_account = "ebs-csi-controller-sa"
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

# OIDC Identity Provider for IRSA
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}

# GitHub Actions OIDC Role
resource "aws_iam_role" "github_actions" {
  count = var.enable_github_actions_role ? 1 : 0
  name  = "${var.cluster_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Federated = var.github_oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:*"
        }
      }
    }]
    Version = "2012-10-17"
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "github_actions_eks" {
  count = var.enable_github_actions_role ? 1 : 0
  name  = "${var.cluster_name}-github-actions-eks-policy"
  role  = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeAddon",
          "eks:ListAddons"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      }
    ]
    Version = "2012-10-17"
  })
}