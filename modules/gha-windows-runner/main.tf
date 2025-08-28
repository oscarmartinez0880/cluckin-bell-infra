terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name = "${var.name_prefix}-gha-win-runner"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Latest Windows Server 2022 AMI (Full) published by AWS
# Note: if you need Containers image, change to: /aws/service/ami-windows-latest/Windows_Server-2022-English-Full-ContainersLatest
data "aws_ssm_parameter" "win2022_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

# Security Group with egress only
resource "aws_security_group" "runner" {
  name        = "${local.name}-sg"
  description = "Security group for Windows GHA runner"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${local.name}-sg" })
}

# IAM Role for instance
resource "aws_iam_role" "runner" {
  name = "${local.name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_policy" "ssm_get_parameter" {
  name        = "${local.name}-ssm-get-parameter"
  description = "Allow instance to read GitHub PAT from SSM"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect : "Allow",
        Action : ["ssm:GetParameter"],
        Resource : "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.github_pat_ssm_parameter_name}"
      },
      {
        Effect : "Allow",
        Action : ["kms:Decrypt"],
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_param" {
  role       = aws_iam_role.runner.name
  policy_arn = aws_iam_policy.ssm_get_parameter.arn
}

resource "aws_iam_instance_profile" "runner" {
  name = "${local.name}-profile"
  role = aws_iam_role.runner.name
}

# User data to register GitHub runner
locals {
  user_data = <<-POWERSHELL
    <powershell>
    Set-ExecutionPolicy Bypass -Scope Process -Force
    $ErrorActionPreference = "Stop"

    # Install NuGet Provider and AWS PowerShell module
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Install-Module -Name AWSPowerShell.NetCore -Force -AllowClobber

    $ParamName = "${var.github_pat_ssm_parameter_name}"
    # Read PAT from SSM (SecureString)
    $pat = (Get-SSMParameter -Name $ParamName -WithDecryption).Parameter.Value

    $owner = "${var.github_owner}"
    $repo  = "${var.github_repo}"
    $headers = @{ "Authorization" = "token $pat"; "Accept" = "application/vnd.github+json" }

    # Get registration token
    $tokenResp = Invoke-RestMethod -Method POST -Headers $headers -Uri "https://api.github.com/repos/$owner/$repo/actions/runners/registration-token"
    $regToken = $tokenResp.token

    New-Item -ItemType Directory -Force -Path C:\actions-runner | Out-Null
    Set-Location C:\actions-runner

    # Fetch latest runner release
    $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/actions/runner/releases/latest" -Headers @{ "Accept" = "application/vnd.github+json" }
    $asset = $latest.assets | Where-Object { $_.name -like "actions-runner-win-x64-*" } | Select-Object -First 1
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "runner.zip"
    Expand-Archive -Path "runner.zip" -DestinationPath . -Force

    # Configure runner
    $labels = "${join(",", var.runner_labels)}"
    cmd.exe /c "config.cmd --url https://github.com/$owner/$repo --token $regToken --unattended --labels $labels --name win-${local.name}"

    # Install and start as service
    cmd.exe /c "svc install"
    cmd.exe /c "svc start"
    </powershell>
  POWERSHELL
}

resource "aws_instance" "runner" {
  ami                         = data.aws_ssm_parameter.win2022_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.runner.id]
  iam_instance_profile        = aws_iam_instance_profile.runner.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  user_data = local.user_data

  tags = merge(var.tags, { Name = local.name })
}