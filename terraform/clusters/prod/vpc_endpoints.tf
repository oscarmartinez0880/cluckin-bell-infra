# S3 gateway endpoint
resource "aws_vpc_endpoint" "s3" {
  provider = aws.prod
  vpc_id   = module.vpc.vpc_id
  service_name = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}

# ECR interface endpoints (api and dkr)
resource "aws_security_group" "vpc_endpoints" {
  provider = aws.prod
  name   = "cb-prod-vpc-endpoints"
  vpc_id = module.vpc.vpc_id
  
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
}

resource "aws_vpc_endpoint" "ecr_api" {
  provider              = aws.prod
  vpc_id                = module.vpc.vpc_id
  service_name          = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type     = "Interface"
  private_dns_enabled   = true
  subnet_ids            = module.vpc.private_subnets
  security_group_ids    = [aws_security_group.vpc_endpoints.id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  provider              = aws.prod
  vpc_id                = module.vpc.vpc_id
  service_name          = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type     = "Interface"
  private_dns_enabled   = true
  subnet_ids            = module.vpc.private_subnets
  security_group_ids    = [aws_security_group.vpc_endpoints.id]
}