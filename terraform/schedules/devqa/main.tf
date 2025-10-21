###############################################################################
# EKS Nodegroup Scheduler for Dev/QA
#
# This module creates a serverless scheduler to scale EKS managed nodegroups
# up and down on a schedule to reduce costs during off-hours.
###############################################################################

terraform {
  required_version = ">= 1.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

###############################################################################
# Data Sources
###############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

###############################################################################
# Lambda Function Package
###############################################################################

# Package the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/scale_nodegroups.py"
  output_path = "${path.module}/lambda/scale_nodegroups.zip"
}

###############################################################################
# IAM Role and Policies for Lambda
###############################################################################

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_role" {
  name = "cb-devqa-eks-scaler-role"

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
    Name = "cb-devqa-eks-scaler-role"
  })
}

# Policy for EKS permissions
resource "aws_iam_role_policy" "lambda_eks_policy" {
  name = "eks-scaler-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:UpdateNodegroupConfig",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = [
          "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}",
          "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:nodegroup/${var.cluster_name}/*/*"
        ]
      }
    ]
  })
}

# Attach AWS managed policy for CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

###############################################################################
# Lambda Function
###############################################################################

resource "aws_lambda_function" "eks_scaler" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "cb-devqa-eks-scaler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "scale_nodegroups.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = var.lambda_timeout

  environment {
    variables = {
      CLUSTER_NAME            = var.cluster_name
      NODEGROUPS              = length(var.nodegroups) > 0 ? jsonencode(var.nodegroups) : ""
      SCALE_UP_MIN_SIZE       = var.scale_up_min_size
      SCALE_UP_DESIRED_SIZE   = var.scale_up_desired_size
      SCALE_UP_MAX_SIZE       = var.scale_up_max_size
      SCALE_DOWN_MIN_SIZE     = var.scale_down_min_size
      SCALE_DOWN_DESIRED_SIZE = var.scale_down_desired_size
      SCALE_DOWN_MAX_SIZE     = var.scale_down_max_size
      WAIT_FOR_ACTIVE         = tostring(var.wait_for_active)
    }
  }

  tags = merge(var.tags, {
    Name = "cb-devqa-eks-scaler"
  })
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.eks_scaler.function_name}"
  retention_in_days = 7

  tags = var.tags
}

###############################################################################
# EventBridge Scheduler
###############################################################################

# IAM role for EventBridge Scheduler
resource "aws_iam_role" "scheduler_role" {
  name = "cb-devqa-eks-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "cb-devqa-eks-scheduler-role"
  })
}

# Policy for EventBridge Scheduler to invoke Lambda
resource "aws_iam_role_policy" "scheduler_lambda_policy" {
  name = "lambda-invoke-policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.eks_scaler.arn
      }
    ]
  })
}

# Scale Up Schedule (Monday-Friday 08:00 AM ET)
resource "aws_scheduler_schedule" "scale_up" {
  name       = "cb-devqa-eks-scale-up"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.scale_up_cron
  schedule_expression_timezone = var.timezone

  target {
    arn      = aws_lambda_function.eks_scaler.arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      action = "scale_up"
    })
  }

  description = "Scale up EKS nodegroups for dev/qa environment (weekday mornings)"
}

# Scale Down Schedule (Monday-Friday 09:00 PM ET)
resource "aws_scheduler_schedule" "scale_down" {
  name       = "cb-devqa-eks-scale-down"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression          = var.scale_down_cron
  schedule_expression_timezone = var.timezone

  target {
    arn      = aws_lambda_function.eks_scaler.arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      action = "scale_down"
    })
  }

  description = "Scale down EKS nodegroups for dev/qa environment (weekday nights)"
}
