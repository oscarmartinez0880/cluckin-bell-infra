# KMS key for EKS secrets envelope encryption in production

resource "aws_kms_key" "eks_secrets_prod" {
  provider                = aws.prod
  description             = "EKS secrets envelope encryption (prod)"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::346746763840:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS service"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "cb-prod-eks-secrets"
    Environment = "prod"
    Purpose     = "eks-secrets-encryption"
    Project     = "cluckn-bell"
  }
}

resource "aws_kms_alias" "eks_secrets_prod" {
  provider      = aws.prod
  name          = "alias/cb-prod-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets_prod.key_id
}

# Variable to enable/disable cluster encryption
variable "enable_cluster_encryption_prod" {
  description = "Enable EKS cluster envelope encryption for secrets in prod"
  type        = bool
  default     = true
}

# Output the KMS key ARN for reference
output "kms_key_arn_prod" {
  description = "ARN of the KMS key used for EKS secrets encryption in prod"
  value       = aws_kms_key.eks_secrets_prod.arn
}