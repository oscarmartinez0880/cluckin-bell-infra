# CI Runners - Windows GitHub Actions runners for Sitecore container builds
# This module creates autoscaling Windows Server 2022 runners for GitHub Actions

# Data source for Windows Server 2022 Core AMI
data "aws_ami" "windows_server_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Core-ContainersLatest-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for current AWS region
data "aws_region" "current" {}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# GitHub App private key for authentication (stored in SSM Parameter Store)
data "aws_ssm_parameter" "github_app_private_key" {
  name = var.github_app_private_key_ssm_parameter
}

# VPC for CI runners
resource "aws_vpc" "ci_runners" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "ci_runners" {
  vpc_id = aws_vpc.ci_runners.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-igw"
  })
}

# Public subnet for NAT Gateway
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.ci_runners.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-public-subnet"
  })
}

# Private subnets for CI runners
resource "aws_subnet" "private" {
  count = var.private_subnet_count

  vpc_id            = aws_vpc.ci_runners.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-private-subnet-${count.index + 1}"
  })
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-nat-eip"
  })

  depends_on = [aws_internet_gateway.ci_runners]
}

# NAT Gateway
resource "aws_nat_gateway" "ci_runners" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-nat"
  })

  depends_on = [aws_internet_gateway.ci_runners]
}

# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.ci_runners.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ci_runners.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-public-rt"
  })
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.ci_runners.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ci_runners.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-private-rt"
  })
}

# Route table associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = var.private_subnet_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security group for CI runners
resource "aws_security_group" "ci_runners" {
  name_prefix = "${var.name_prefix}-ci-runners-"
  vpc_id      = aws_vpc.ci_runners.id

  # Outbound internet access for package downloads, container pulls, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optional: Allow SSM access for debugging and maintenance
  dynamic "ingress" {
    for_each = var.enable_ssm_access ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [var.vpc_cidr]
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# VPC Endpoints for ECR and S3 (optional for reliability)
resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.ci_runners.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-ecr-api-endpoint"
  })
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.ci_runners.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-ecr-dkr-endpoint"
  })
}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id            = aws_vpc.ci_runners.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-s3-endpoint"
  })
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name_prefix = "${var.name_prefix}-ci-runners-endpoints-"
  vpc_id      = aws_vpc.ci_runners.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ci_runners.id]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runners-endpoints-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# IAM role for CI runner instances
resource "aws_iam_role" "ci_runner_instance" {
  name = "${var.name_prefix}-ci-runner-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for ECR access (minimal permissions)
resource "aws_iam_role_policy" "ci_runner_ecr" {
  name = "${var.name_prefix}-ci-runner-ecr-policy"
  role = aws_iam_role.ci_runner_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# Optional SSM policy for patching and logs
resource "aws_iam_role_policy_attachment" "ci_runner_ssm" {
  count = var.enable_ssm_access ? 1 : 0

  role       = aws_iam_role.ci_runner_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for CI runners
resource "aws_iam_instance_profile" "ci_runner" {
  name = "${var.name_prefix}-ci-runner-instance-profile"
  role = aws_iam_role.ci_runner_instance.name

  tags = var.tags
}

# User data script for Windows runners
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.ps1", {
    github_app_id               = var.github_app_id
    github_app_installation_id  = var.github_app_installation_id
    github_app_private_key      = data.aws_ssm_parameter.github_app_private_key.value
    runner_group                = var.runner_group
    runner_labels               = join(",", var.runner_labels)
    runner_name_prefix          = var.runner_name_prefix
    github_repository_allowlist = join(",", var.github_repository_allowlist)
  }))
}

# Launch template for CI runners
resource "aws_launch_template" "ci_runner" {
  name_prefix   = "${var.name_prefix}-ci-runner-"
  image_id      = data.aws_ami.windows_server_2022.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.ci_runners.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ci_runner.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = local.user_data

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-ci-runner"
      Type = "github-actions-runner"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name_prefix}-ci-runner-volume"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ci-runner-template"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for CI runners
resource "aws_autoscaling_group" "ci_runner" {
  name                      = "${var.name_prefix}-ci-runner-asg"
  vpc_zone_identifier       = aws_subnet.private[*].id
  target_group_arns         = []
  health_check_type         = "EC2"
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.ci_runner.id
    version = "$Latest"
  }

  # Instance refresh configuration for updates
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-ci-runner-asg"
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Lambda function for webhook handling (if using webhook pattern)
resource "aws_lambda_function" "webhook" {
  count = var.enable_webhook ? 1 : 0

  filename      = "${path.module}/webhook.zip"
  function_name = "${var.name_prefix}-ci-runner-webhook"
  role          = aws_iam_role.webhook_lambda[0].arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 60

  environment {
    variables = {
      ASG_NAME = aws_autoscaling_group.ci_runner.name
    }
  }

  tags = var.tags
}

# IAM role for webhook Lambda function
resource "aws_iam_role" "webhook_lambda" {
  count = var.enable_webhook ? 1 : 0

  name = "${var.name_prefix}-ci-runner-webhook-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for webhook Lambda
resource "aws_iam_role_policy" "webhook_lambda" {
  count = var.enable_webhook ? 1 : 0

  name = "${var.name_prefix}-ci-runner-webhook-policy"
  role = aws_iam_role.webhook_lambda[0].id

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
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:DescribeAutoScalingGroups"
        ]
        Resource = aws_autoscaling_group.ci_runner.arn
      }
    ]
  })
}

# API Gateway for webhook endpoint
resource "aws_api_gateway_rest_api" "webhook" {
  count = var.enable_webhook ? 1 : 0

  name        = "${var.name_prefix}-ci-runner-webhook"
  description = "GitHub Actions webhook for CI runners"

  tags = var.tags
}

resource "aws_api_gateway_resource" "webhook" {
  count = var.enable_webhook ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.webhook[0].id
  parent_id   = aws_api_gateway_rest_api.webhook[0].root_resource_id
  path_part   = "webhook"
}

resource "aws_api_gateway_method" "webhook_post" {
  count = var.enable_webhook ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.webhook[0].id
  resource_id   = aws_api_gateway_resource.webhook[0].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "webhook" {
  count = var.enable_webhook ? 1 : 0

  rest_api_id             = aws_api_gateway_rest_api.webhook[0].id
  resource_id             = aws_api_gateway_resource.webhook[0].id
  http_method             = aws_api_gateway_method.webhook_post[0].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.webhook[0].invoke_arn
}

resource "aws_api_gateway_deployment" "webhook" {
  count = var.enable_webhook ? 1 : 0

  depends_on = [
    aws_api_gateway_method.webhook_post[0],
    aws_api_gateway_integration.webhook[0]
  ]

  rest_api_id = aws_api_gateway_rest_api.webhook[0].id

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway stage
resource "aws_api_gateway_stage" "webhook" {
  count = var.enable_webhook ? 1 : 0

  deployment_id = aws_api_gateway_deployment.webhook[0].id
  rest_api_id   = aws_api_gateway_rest_api.webhook[0].id
  stage_name    = "prod"

  tags = var.tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "webhook" {
  count = var.enable_webhook ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.webhook[0].execution_arn}/*/*"
}