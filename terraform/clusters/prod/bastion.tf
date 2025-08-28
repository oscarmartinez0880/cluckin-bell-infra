# Bastion host for prod dedicated access using SSM Session Manager

# Data source for Amazon Linux 2023 AMI
data "aws_ami" "al2023_prod" {
  provider    = aws.prod
  most_recent = true
  owners      = ["137112412989"]  # Amazon
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
}

# IAM role for bastion
data "aws_iam_policy_document" "bastion_assume_prod" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion_prod" {
  provider           = aws.prod
  name               = "cb-prod-bastion"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_prod.json

  tags = {
    Name        = "cb-prod-bastion"
    Environment = "prod"
    Purpose     = "ssm-bastion"
    Project     = "cluckn-bell"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_prod" {
  provider   = aws.prod
  role       = aws_iam_role.bastion_prod.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_prod" {
  provider = aws.prod
  name     = "cb-prod-bastion"
  role     = aws_iam_role.bastion_prod.name

  tags = {
    Name        = "cb-prod-bastion"
    Environment = "prod"
    Purpose     = "ssm-bastion"
    Project     = "cluckn-bell"
  }
}

# Security group for bastion
resource "aws_security_group" "bastion_prod" {
  provider    = aws.prod
  name        = "cb-prod-bastion"
  description = "Security group for Production bastion host"
  vpc_id      = module.vpc.vpc_id

  # No inbound rules - access via SSM Session Manager only

  # All outbound traffic allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cb-prod-bastion"
    Environment = "prod"
    Purpose     = "ssm-bastion"
    Project     = "cluckn-bell"
  }
}

# Bastion EC2 instance
resource "aws_instance" "bastion_prod" {
  provider                    = aws.prod
  ami                         = data.aws_ami.al2023_prod.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_prod.name
  vpc_security_group_ids      = [aws_security_group.bastion_prod.id]

  metadata_options {
    http_tokens = "required"  # Enforce IMDSv2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true

    tags = {
      Name        = "cb-prod-bastion-root"
      Environment = "prod"
      Project     = "cluckn-bell"
    }
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    
    # Ensure SSM agent is running
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Set hostname
    hostnamectl set-hostname cb-prod-bastion
    
    # Create MOTD
    cat > /etc/motd << 'MOTD'
===============================================
 Cluckin Bell Production Bastion Host
===============================================
This instance provides secure access to Production
environment via AWS Systems Manager.

Use Session Manager for shell access:
  aws ssm start-session --target INSTANCE_ID

For port forwarding to internal services:
  aws ssm start-session --target INSTANCE_ID \
    --document-name AWS-StartPortForwardingSession \
    --parameters portNumber=80,localPortNumber=8080

Environment: Production
Access: internal.cluckn-bell.com services
===============================================
MOTD
  EOF
  )

  tags = {
    Name        = "cb-prod-bastion"
    Environment = "prod"
    Purpose     = "ssm-bastion"
    Project     = "cluckn-bell"
    OS          = "amazon-linux-2023"
  }

  depends_on = [module.vpc]
}

# Output bastion instance ID for SSM access
output "bastion_prod_instance_id" {
  description = "Instance ID of the Production bastion host for SSM access"
  value       = aws_instance.bastion_prod.id
}