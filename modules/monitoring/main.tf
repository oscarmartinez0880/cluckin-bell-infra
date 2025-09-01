terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "log_groups" {
  for_each = var.log_groups

  name              = each.key
  retention_in_days = lookup(each.value, "retention_in_days", 7)
  kms_key_id        = lookup(each.value, "kms_key_id", null)

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

# CloudWatch Dashboards
resource "aws_cloudwatch_dashboard" "dashboards" {
  for_each = var.dashboards

  dashboard_name = each.key
  dashboard_body = each.value.body
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "alarms" {
  for_each = var.metric_alarms

  alarm_name          = each.key
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = each.value.period
  statistic           = lookup(each.value, "statistic", null)
  threshold           = each.value.threshold
  alarm_description   = lookup(each.value, "alarm_description", "This metric monitors ${each.value.metric_name}")
  alarm_actions       = lookup(each.value, "alarm_actions", [])
  ok_actions          = lookup(each.value, "ok_actions", [])

  insufficient_data_actions = lookup(each.value, "insufficient_data_actions", [])
  treat_missing_data        = lookup(each.value, "treat_missing_data", "missing")
  datapoints_to_alarm       = lookup(each.value, "datapoints_to_alarm", null)

  dynamic "metric_query" {
    for_each = lookup(each.value, "metric_queries", [])
    content {
      id          = metric_query.value.id
      return_data = lookup(metric_query.value, "return_data", null)

      dynamic "metric" {
        for_each = lookup(metric_query.value, "metric", null) != null ? [metric_query.value.metric] : []
        content {
          metric_name = metric.value.metric_name
          namespace   = metric.value.namespace
          period      = metric.value.period
          stat        = metric.value.stat
          unit        = lookup(metric.value, "unit", null)
          dimensions  = lookup(metric.value, "dimensions", {})
        }
      }
    }
  }

  dimensions = lookup(each.value, "dimensions", {})

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

# SNS Topics for notifications
resource "aws_sns_topic" "notification_topics" {
  for_each = var.sns_topics

  name         = each.key
  display_name = lookup(each.value, "display_name", each.key)

  kms_master_key_id = lookup(each.value, "kms_master_key_id", null)

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "subscriptions" {
  for_each = local.sns_subscriptions

  topic_arn = aws_sns_topic.notification_topics[each.value.topic_key].arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  filter_policy = lookup(each.value, "filter_policy", null)
}

# CloudWatch Composite Alarms
resource "aws_cloudwatch_composite_alarm" "composite_alarms" {
  for_each = var.composite_alarms

  alarm_name        = each.key
  alarm_description = lookup(each.value, "alarm_description", "Composite alarm for ${each.key}")
  alarm_rule        = each.value.alarm_rule

  actions_enabled           = lookup(each.value, "actions_enabled", true)
  alarm_actions             = lookup(each.value, "alarm_actions", [])
  ok_actions                = lookup(each.value, "ok_actions", [])
  insufficient_data_actions = lookup(each.value, "insufficient_data_actions", [])

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

# CloudWatch Log Metric Filters
resource "aws_cloudwatch_log_metric_filter" "metric_filters" {
  for_each = var.log_metric_filters

  name           = each.key
  log_group_name = each.value.log_group_name
  pattern        = each.value.pattern

  metric_transformation {
    name      = each.value.metric_transformation.name
    namespace = each.value.metric_transformation.namespace
    value     = each.value.metric_transformation.value
    unit      = lookup(each.value.metric_transformation, "unit", "None")
  }
}

# Application Insights
resource "aws_applicationinsights_application" "applications" {
  for_each = var.application_insights

  resource_group_name = each.value.resource_group_name
  auto_config_enabled = lookup(each.value, "auto_config_enabled", true)
  auto_create         = lookup(each.value, "auto_create", true)
  cwe_monitor_enabled = lookup(each.value, "cwe_monitor_enabled", true)

  tags = merge(var.tags, lookup(each.value, "tags", {}))
}

# Local values for processing
locals {
  # Flatten SNS subscriptions
  sns_subscriptions = merge([
    for topic_key, topic_config in var.sns_topics : {
      for idx, subscription in lookup(topic_config, "subscriptions", []) :
      "${topic_key}-${idx}" => merge(subscription, {
        topic_key = topic_key
      })
    }
  ]...)
}

# Container Insights Resources
# CloudWatch Log Groups for Container Insights
resource "aws_cloudwatch_log_group" "container_insights_performance" {
  count = var.container_insights.enabled ? 1 : 0

  name              = "/aws/containerinsights/${var.container_insights.cluster_name}/performance"
  retention_in_days = var.container_insights.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "container_insights_application" {
  count = var.container_insights.enabled ? 1 : 0

  name              = "/aws/containerinsights/${var.container_insights.cluster_name}/application"
  retention_in_days = var.container_insights.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "container_insights_dataplane" {
  count = var.container_insights.enabled ? 1 : 0

  name              = "/aws/containerinsights/${var.container_insights.cluster_name}/dataplane"
  retention_in_days = var.container_insights.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "container_insights_host" {
  count = var.container_insights.enabled ? 1 : 0

  name              = "/aws/containerinsights/${var.container_insights.cluster_name}/host"
  retention_in_days = var.container_insights.log_retention_days

  tags = var.tags
}

# Kubernetes namespace for CloudWatch Agent and Fluent Bit
resource "kubernetes_namespace" "amazon_cloudwatch" {
  count = var.container_insights.enabled ? 1 : 0

  metadata {
    name = "amazon-cloudwatch"
    labels = {
      name = "amazon-cloudwatch"
    }
  }
}

# CloudWatch Agent for metrics collection
resource "helm_release" "cloudwatch_agent" {
  count = var.container_insights.enabled && var.container_insights.enable_cloudwatch_agent ? 1 : 0

  name       = "cloudwatch-agent"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-cloudwatch-metrics"
  version    = var.container_insights.cloudwatch_agent_version
  namespace  = kubernetes_namespace.amazon_cloudwatch[0].metadata[0].name

  set {
    name  = "clusterName"
    value = var.container_insights.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.container_insights.aws_region
  }

  dynamic "set" {
    for_each = var.container_insights.cloudwatch_agent_role_arn != "" ? [1] : []
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.container_insights.cloudwatch_agent_role_arn
    }
  }

  depends_on = [kubernetes_namespace.amazon_cloudwatch]
}

# Fluent Bit for log collection
resource "helm_release" "fluent_bit" {
  count = var.container_insights.enabled && var.container_insights.enable_fluent_bit ? 1 : 0

  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  version    = var.container_insights.fluent_bit_version
  namespace  = kubernetes_namespace.amazon_cloudwatch[0].metadata[0].name

  set {
    name  = "cloudWatchLogs.enabled"
    value = "true"
  }

  set {
    name  = "cloudWatchLogs.region"
    value = var.container_insights.aws_region
  }

  set {
    name  = "cloudWatchLogs.logGroupName"
    value = "/aws/containerinsights/${var.container_insights.cluster_name}/application"
  }

  dynamic "set" {
    for_each = var.container_insights.fluent_bit_role_arn != "" ? [1] : []
    content {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.container_insights.fluent_bit_role_arn
    }
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