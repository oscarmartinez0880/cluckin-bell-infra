# Bastion host for dev/qa shared access using SSM Session Manager

# Data source for Amazon Linux 2023 AMI
data "aws_ami" "al2023_devqa" {
  provider    = aws.devqa
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
data "aws_iam_policy_document" "bastion_assume_devqa" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion_devqa" {
  provider           = aws.devqa
  name               = "cb-devqa-bastion"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_devqa.json

  tags = {
    Name        = "cb-devqa-bastion"
    Environment = "dev-qa"
    Purpose     = "ssm-bastion"
    Project     = "cluckn-bell"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_devqa" {
  provider   = aws.devqa
  role       = aws_iam_role.bastion_devqa.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion_devqa" {
  provider = aws.devqa
  name     = "cb-devqa-bastion"
  role     = aws_iam_role.bastion_devqa.name

  tags = {
    Name        = "cb-devqa-bastion"
    Environment = "dev-qa"
    Purpose     = "ssm-bastion"
    Project     = "cluckn-bell"
  }
}

# Security group for bastion
resource "aws_security_group" "bastion_devqa" {
  provider    = aws.devqa
  name        = "cb-devqa-bastion"
  description = "Security group for Dev/QA bastion host"
  vpc_id      = module.vpc_devqa.vpc_id

  # No inbound rules - access via SSM Session Manager only

  # All outbound traffic allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "cb-devqa-bastion"
    Environment = "dev-qa"
    Purpose     = "ssm-bastion"
    Project     = "cluckn-bell"
  }
}

# Bastion EC2 instance
resource "aws_instance" "bastion_devqa" {
  provider                    = aws.devqa
  ami                         = data.aws_ami.al2023_devqa.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc_devqa.public_subnets[0]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion_devqa.name
  vpc_security_group_ids      = [aws_security_group.bastion_devqa.id]

  metadata_options {
    http_tokens = "required"  # Enforce IMDSv2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true

    tags = {
      Name        = "cb-devqa-bastion-root"
      Environment = "dev-qa"
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
    hostnamectl set-hostname cb-devqa-bastion
    
    # Create MOTD
    cat > /etc/motd << 'MOTD'
===============================================
 Cluckin Bell Dev/QA Bastion Host
===============================================
This instance provides secure access to Dev/QA
environments via AWS Systems Manager.

Use Session Manager for shell access:
  aws ssm start-session --target INSTANCE_ID

For port forwarding to internal services:
  aws ssm start-session --target INSTANCE_ID \
    --document-name AWS-StartPortForwardingSession \
    --parameters portNumber=80,localPortNumber=8080

Environment: Dev/QA Shared
Access: internal.dev.cluckn-bell.com services
===============================================
MOTD
  EOF
  )

  tags = {
    Name        = "cb-devqa-bastion"
    Environment = "dev-qa"
    Purpose     = "ssm-bastion"
    Project     = "cluckn-bell"
    OS          = "amazon-linux-2023"
  }

  depends_on = [module.vpc_devqa]
}

# Output bastion instance ID for SSM access
output "bastion_devqa_instance_id" {
  description = "Instance ID of the Dev/QA bastion host for SSM access"
  value       = aws_instance.bastion_devqa.id
}