terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name              = "alerts-${var.environment}"
  display_name      = "Alertmanager notifications for ${var.environment}"
  kms_master_key_id = aws_kms_key.sns.id

  tags = merge(var.tags, {
    Name        = "alerts-${var.environment}"
    Environment = var.environment
    Purpose     = "alerting"
  })
}

# KMS key for SNS encryption
resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS topic alerts-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name        = "sns-alerts-${var.environment}"
    Environment = var.environment
  })
}

resource "aws_kms_alias" "sns" {
  name          = "alias/sns-alerts-${var.environment}"
  target_key_id = aws_kms_key.sns.key_id
}

# Email subscription
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SMS subscription
resource "aws_sns_topic_subscription" "sms" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "sms"
  endpoint  = var.alert_phone
}

# Lambda function for Alertmanager webhook
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

resource "aws_lambda_function" "alertmanager_webhook" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "alertmanager-webhook-${var.environment}"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }

  tags = merge(var.tags, {
    Name        = "alertmanager-webhook-${var.environment}"
    Environment = var.environment
    Purpose     = "alerting"
  })
}

# IAM role for Lambda
resource "aws_iam_role" "lambda" {
  name = "alertmanager-webhook-lambda-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "alertmanager-webhook-lambda-${var.environment}"
    Environment = var.environment
  })
}

# Lambda execution policy
resource "aws_iam_role_policy" "lambda_execution" {
  name = "lambda-execution"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/alertmanager-webhook-${var.environment}:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/alertmanager-webhook-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "alertmanager-webhook-${var.environment}"
    Environment = var.environment
  })
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "webhook" {
  name          = "alertmanager-webhook-${var.environment}"
  protocol_type = "HTTP"
  description   = "Alertmanager webhook receiver for ${var.environment}"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key"]
    max_age       = 300
  }

  tags = merge(var.tags, {
    Name        = "alertmanager-webhook-${var.environment}"
    Environment = var.environment
    Purpose     = "alerting"
  })
}

# API Gateway stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.webhook.id
  name        = "$default"
  auto_deploy = true

  tags = merge(var.tags, {
    Name        = "alertmanager-webhook-${var.environment}"
    Environment = var.environment
  })
}

# API Gateway integration with Lambda
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.webhook.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.alertmanager_webhook.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# API Gateway route
resource "aws_apigatewayv2_route" "webhook" {
  api_id    = aws_apigatewayv2_api.webhook.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alertmanager_webhook.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook.execution_arn}/*/*/webhook"
}

# Secrets Manager secret for webhook URL
resource "aws_secretsmanager_secret" "webhook_url" {
  name        = "alertmanager/webhook-url-${var.environment}"
  description = "Alertmanager webhook URL for ${var.environment}"

  tags = merge(var.tags, {
    Name        = "alertmanager-webhook-url-${var.environment}"
    Environment = var.environment
    Purpose     = "alerting"
  })
}

resource "aws_secretsmanager_secret_version" "webhook_url" {
  secret_id     = aws_secretsmanager_secret.webhook_url.id
  secret_string = "${aws_apigatewayv2_api.webhook.api_endpoint}/webhook"
}
