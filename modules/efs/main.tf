terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# KMS key for EFS encryption
resource "aws_kms_key" "efs" {
  count = var.encrypted && var.kms_key_id == null ? 1 : 0

  description             = "KMS key for EFS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name}-efs-key"
  })
}

resource "aws_kms_alias" "efs" {
  count = var.encrypted && var.kms_key_id == null ? 1 : 0

  name          = "alias/${var.name}-efs-key"
  target_key_id = aws_kms_key.efs[0].key_id
}

# EFS File System
resource "aws_efs_file_system" "main" {
  creation_token   = var.creation_token
  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode

  # Encryption configuration
  encrypted  = var.encrypted
  kms_key_id = var.encrypted ? coalesce(var.kms_key_id, aws_kms_key.efs[0].arn) : null

  # Lifecycle management
  dynamic "lifecycle_policy" {
    for_each = var.lifecycle_policy != null ? [var.lifecycle_policy] : []
    content {
      transition_to_ia                    = lookup(lifecycle_policy.value, "transition_to_ia", null)
      transition_to_primary_storage_class = lookup(lifecycle_policy.value, "transition_to_primary_storage_class", null)
    }
  }

  # Backup policy - removed invalid attribute
  # AWS EFS backup is managed separately

  tags = merge(var.tags, {
    Name = var.name
  })
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "${var.name}-efs-"
  description = "Security group for EFS mount targets"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
    cidr_blocks     = var.allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-efs-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EFS Mount Targets
resource "aws_efs_mount_target" "main" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group.efs.id]
}

# EFS Access Points
resource "aws_efs_access_point" "access_points" {
  for_each = var.access_points

  file_system_id = aws_efs_file_system.main.id

  dynamic "posix_user" {
    for_each = lookup(each.value, "posix_user", null) != null ? [each.value.posix_user] : []
    content {
      gid            = posix_user.value.gid
      uid            = posix_user.value.uid
      secondary_gids = lookup(posix_user.value, "secondary_gids", null)
    }
  }

  dynamic "root_directory" {
    for_each = lookup(each.value, "root_directory", null) != null ? [each.value.root_directory] : []
    content {
      path = lookup(root_directory.value, "path", "/")

      dynamic "creation_info" {
        for_each = lookup(root_directory.value, "creation_info", null) != null ? [root_directory.value.creation_info] : []
        content {
          owner_gid   = creation_info.value.owner_gid
          owner_uid   = creation_info.value.owner_uid
          permissions = creation_info.value.permissions
        }
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${each.key}"
  })
}

# EFS File System Policy
resource "aws_efs_file_system_policy" "policy" {
  count = var.policy != null ? 1 : 0

  file_system_id = aws_efs_file_system.main.id
  policy         = var.policy
}

# EFS Backup Policy
resource "aws_efs_backup_policy" "policy" {
  count = var.enable_backup_policy ? 1 : 0

  file_system_id = aws_efs_file_system.main.id

  backup_policy {
    status = "ENABLED"
  }
}