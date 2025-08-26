variable "log_groups" {
  description = "Map of CloudWatch log groups to create"
  type = map(object({
    retention_in_days = optional(number, 7)
    kms_key_id        = optional(string, null)
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "dashboards" {
  description = "Map of CloudWatch dashboards to create"
  type = map(object({
    body = string
  }))
  default = {}
}

variable "metric_alarms" {
  description = "Map of CloudWatch metric alarms to create"
  type = map(object({
    comparison_operator       = string
    evaluation_periods        = number
    metric_name               = optional(string, null)
    namespace                 = optional(string, null)
    period                    = optional(number, null)
    statistic                 = optional(string, null)
    threshold                 = number
    alarm_description         = optional(string, null)
    alarm_actions             = optional(list(string), [])
    ok_actions                = optional(list(string), [])
    insufficient_data_actions = optional(list(string), [])
    treat_missing_data        = optional(string, "missing")
    datapoints_to_alarm       = optional(number, null)
    dimensions                = optional(map(string), {})
    metric_queries = optional(list(object({
      id          = string
      return_data = optional(bool, null)
      metric = optional(object({
        metric_name = string
        namespace   = string
        period      = number
        stat        = string
        unit        = optional(string, null)
        dimensions  = optional(map(string), {})
      }), null)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "sns_topics" {
  description = "Map of SNS topics to create for notifications"
  type = map(object({
    display_name      = optional(string, null)
    kms_master_key_id = optional(string, null)
    subscriptions = optional(list(object({
      protocol      = string
      endpoint      = string
      filter_policy = optional(string, null)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "composite_alarms" {
  description = "Map of CloudWatch composite alarms to create"
  type = map(object({
    alarm_rule                = string
    alarm_description         = optional(string, null)
    actions_enabled           = optional(bool, true)
    alarm_actions             = optional(list(string), [])
    ok_actions                = optional(list(string), [])
    insufficient_data_actions = optional(list(string), [])
    tags                      = optional(map(string), {})
  }))
  default = {}
}

variable "log_metric_filters" {
  description = "Map of CloudWatch log metric filters to create"
  type = map(object({
    log_group_name = string
    pattern        = string
    metric_transformation = object({
      name      = string
      namespace = string
      value     = string
      unit      = optional(string, "None")
    })
  }))
  default = {}
}

variable "application_insights" {
  description = "Map of Application Insights applications to create"
  type = map(object({
    resource_group_name = string
    auto_config_enabled = optional(bool, true)
    auto_create         = optional(bool, true)
    cwe_monitor_enabled = optional(bool, true)
    tags                = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}