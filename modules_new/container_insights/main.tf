terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# CloudWatch Log Group for Container Insights
resource "aws_cloudwatch_log_group" "container_insights" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "application_logs" {
  name              = "/aws/containerinsights/${var.cluster_name}/application"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# CloudWatch Log Group for DataPlane logs
resource "aws_cloudwatch_log_group" "dataplane_logs" {
  name              = "/aws/containerinsights/${var.cluster_name}/dataplane"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# CloudWatch Log Group for Host logs
resource "aws_cloudwatch_log_group" "host_logs" {
  name              = "/aws/containerinsights/${var.cluster_name}/host"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Kubernetes namespace for CloudWatch Agent and Fluent Bit
resource "kubernetes_namespace" "amazon_cloudwatch" {
  metadata {
    name = "amazon-cloudwatch"
    labels = {
      name = "amazon-cloudwatch"
    }
  }
}

# CloudWatch Agent for metrics collection
resource "helm_release" "cloudwatch_agent" {
  count = var.enable_cloudwatch_agent ? 1 : 0

  name       = "cloudwatch-agent"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-cloudwatch-metrics"
  version    = var.cloudwatch_agent_version
  namespace  = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cloudwatch_agent_role_arn
  }

  depends_on = [kubernetes_namespace.amazon_cloudwatch]
}

# Fluent Bit for log collection
resource "helm_release" "fluent_bit" {
  count = var.enable_fluent_bit ? 1 : 0

  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  version    = var.fluent_bit_version
  namespace  = kubernetes_namespace.amazon_cloudwatch.metadata[0].name

  set {
    name  = "cloudWatchLogs.enabled"
    value = "true"
  }

  set {
    name  = "cloudWatchLogs.region"
    value = var.aws_region
  }

  set {
    name  = "cloudWatchLogs.logGroupName"
    value = "/aws/containerinsights/${var.cluster_name}/application"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.fluent_bit_role_arn
  }

  set {
    name  = "firehose.enabled"
    value = "false"
  }

  set {
    name  = "kinesis.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.amazon_cloudwatch]
}
