output "db_instance_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.main.arn
}

output "db_instance_availability_zone" {
  description = "The availability zone of the RDS instance"
  value       = aws_db_instance.main.availability_zone
}

output "db_instance_endpoint" {
  description = "The RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_hosted_zone_id" {
  description = "The canonical hosted zone ID of the DB instance (to be used in a Route 53 Alias record)"
  value       = aws_db_instance.main.hosted_zone_id
}

output "db_instance_id" {
  description = "The RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_resource_id" {
  description = "The RDS Resource ID of this instance"
  value       = aws_db_instance.main.resource_id
}

output "db_instance_status" {
  description = "The RDS instance status"
  value       = aws_db_instance.main.status
}

output "db_instance_name" {
  description = "The database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "The master username for the database"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_instance_password" {
  description = "The database password (this password may be old, because Terraform doesn't track it after initial creation)"
  value       = var.manage_master_user_password ? null : aws_db_instance.main.password
  sensitive   = true
}

output "db_instance_port" {
  description = "The database port"
  value       = aws_db_instance.main.port
}

output "db_subnet_group_id" {
  description = "The db subnet group name"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "The ARN of the db subnet group"
  value       = aws_db_subnet_group.main.arn
}

output "db_parameter_group_id" {
  description = "The db parameter group id"
  value       = var.create_db_parameter_group ? aws_db_parameter_group.main[0].id : null
}

output "db_parameter_group_arn" {
  description = "The ARN of the db parameter group"
  value       = var.create_db_parameter_group ? aws_db_parameter_group.main[0].arn : null
}

output "enhanced_monitoring_iam_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the monitoring role"
  value       = var.monitoring_interval > 0 ? aws_iam_role.enhanced_monitoring[0].arn : null
}

output "db_instance_cloudwatch_log_groups" {
  description = "Map of CloudWatch log groups created and their attributes"
  value       = aws_cloudwatch_log_group.rds
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.rds.id
}