# VPC Endpoints for Production (parity with dev/qa)

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints_prod" {
  provider    = aws.prod
  name        = "cb-prod-vpc-endpoints"
  description = "Security group for VPC endpoints in production"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cb-prod-vpc-endpoints"
    Environment = "prod"
    Purpose     = "vpc-endpoints"
    Project     = "cluckn-bell"
  }
}

# S3 Gateway endpoint
resource "aws_vpc_endpoint" "s3_prod" {
  provider    = aws.prod
  vpc_id      = module.vpc.vpc_id
  service_name = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  
  route_table_ids = module.vpc.private_route_table_ids

  tags = {
    Name        = "cb-prod-s3-gateway-endpoint"
    Environment = "prod"
    Service     = "s3"
    Project     = "cluckn-bell"
  }
}

# ECR API Interface endpoint
resource "aws_vpc_endpoint" "ecr_api_prod" {
  provider            = aws.prod
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints_prod.id]
  private_dns_enabled = true

  tags = {
    Name        = "cb-prod-ecr-api-endpoint"
    Environment = "prod"
    Service     = "ecr-api"
    Project     = "cluckn-bell"
  }
}

# ECR Docker Interface endpoint
resource "aws_vpc_endpoint" "ecr_dkr_prod" {
  provider            = aws.prod
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints_prod.id]
  private_dns_enabled = true

  tags = {
    Name        = "cb-prod-ecr-dkr-endpoint"
    Environment = "prod"
    Service     = "ecr-dkr"
    Project     = "cluckn-bell"
  }
}

# SSM Interface endpoint (for bastion connectivity)
resource "aws_vpc_endpoint" "ssm_prod" {
  provider            = aws.prod
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnets[0]]  # Single AZ to minimize cost
  security_group_ids  = [aws_security_group.vpc_endpoints_prod.id]
  private_dns_enabled = true

  tags = {
    Name        = "cb-prod-ssm-endpoint"
    Environment = "prod"
    Service     = "ssm"
    Project     = "cluckn-bell"
  }
}

# SSM Messages Interface endpoint
resource "aws_vpc_endpoint" "ssmmessages_prod" {
  provider            = aws.prod
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.us-east-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnets[0]]  # Single AZ to minimize cost
  security_group_ids  = [aws_security_group.vpc_endpoints_prod.id]
  private_dns_enabled = true

  tags = {
    Name        = "cb-prod-ssmmessages-endpoint"
    Environment = "prod"
    Service     = "ssm-messages"
    Project     = "cluckn-bell"
  }
}

# EC2 Messages Interface endpoint
resource "aws_vpc_endpoint" "ec2messages_prod" {
  provider            = aws.prod
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.us-east-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [module.vpc.private_subnets[0]]  # Single AZ to minimize cost
  security_group_ids  = [aws_security_group.vpc_endpoints_prod.id]
  private_dns_enabled = true

  tags = {
    Name        = "cb-prod-ec2messages-endpoint"
    Environment = "prod"
    Service     = "ec2-messages"
    Project     = "cluckn-bell"
  }
}