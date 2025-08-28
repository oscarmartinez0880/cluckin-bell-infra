terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for Amazon Linux 2023 AMI
data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# Security group for SSM bastion
resource "aws_security_group" "bastion" {
  name_prefix = "${var.name}-bastion-"
  description = "Security group for SSM bastion host"
  vpc_id      = var.vpc_id

  # No inbound rules - access via SSM Session Manager only

  # All outbound traffic allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name        = "${var.name}-bastion-sg"
    Purpose     = "ssm-bastion"
    Environment = var.environment
  })
}

# IAM role for SSM bastion
resource "aws_iam_role" "bastion" {
  name = "${var.name}-bastion-role"

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

  tags = merge(var.tags, {
    Name        = "${var.name}-bastion-role"
    Purpose     = "ssm-bastion"
    Environment = var.environment
  })
}

# Attach AmazonSSMManagedInstanceCore policy
resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for bastion
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = merge(var.tags, {
    Name        = "${var.name}-bastion-profile"
    Purpose     = "ssm-bastion"
    Environment = var.environment
  })
}

# SSM bastion EC2 instance
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = false

  # Enable detailed monitoring
  monitoring = true

  # User data to configure SSM agent (should be pre-installed on AL2023)
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    
    # Ensure SSM agent is running
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Install session manager plugin dependencies
    yum install -y curl
    
    # Configure hostname
    hostnamectl set-hostname ${var.name}-bastion-${var.environment}
    
    # Create a motd
    cat > /etc/motd << 'MOTD'
===============================================
 SSM Bastion Host - ${var.environment} Environment
===============================================
This instance is managed via AWS Systems Manager.
Use Session Manager for secure shell access.

Environment: ${var.environment}
Instance: ${var.name}-bastion
Purpose: Secure access to private resources

For port forwarding examples, see the README.
===============================================
MOTD
  EOF
  )

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true

    tags = merge(var.tags, {
      Name        = "${var.name}-bastion-root-volume"
      Environment = var.environment
    })
  }

  tags = merge(var.tags, {
    Name        = "${var.name}-bastion"
    Purpose     = "ssm-bastion"
    Environment = var.environment
    OS          = "amazon-linux-2023"
  })
}