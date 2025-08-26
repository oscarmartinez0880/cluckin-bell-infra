output "efs_file_system_id" {
  description = "The ID that identifies the file system"
  value       = aws_efs_file_system.main.id
}

output "efs_file_system_arn" {
  description = "Amazon Resource Name of the file system"
  value       = aws_efs_file_system.main.arn
}

output "efs_file_system_dns_name" {
  description = "The DNS name for the filesystem"
  value       = aws_efs_file_system.main.dns_name
}

output "efs_mount_target_ids" {
  description = "List of IDs of the EFS mount targets"
  value       = aws_efs_mount_target.main[*].id
}

output "efs_mount_target_dns_names" {
  description = "List of DNS names for the EFS mount targets"
  value       = aws_efs_mount_target.main[*].dns_name
}

output "efs_mount_target_ips" {
  description = "List of IP addresses at which the file system may be mounted via the mount target"
  value       = aws_efs_mount_target.main[*].ip_address
}

output "efs_access_point_ids" {
  description = "The IDs of the EFS access points"
  value       = { for k, v in aws_efs_access_point.access_points : k => v.id }
}

output "efs_access_point_arns" {
  description = "The ARNs of the EFS access points"
  value       = { for k, v in aws_efs_access_point.access_points : k => v.arn }
}

output "security_group_id" {
  description = "The ID of the security group for EFS mount targets"
  value       = aws_security_group.efs.id
}

output "kms_key_id" {
  description = "The ID of the KMS key used for encryption"
  value       = var.encrypted ? coalesce(var.kms_key_id, try(aws_kms_key.efs[0].key_id, null)) : null
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = var.encrypted ? coalesce(var.kms_key_id, try(aws_kms_key.efs[0].arn, null)) : null
}