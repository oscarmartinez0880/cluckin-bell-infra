output "redis_replication_group_id" {
  description = "The ID of the ElastiCache Redis replication group"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].id : null
}

output "redis_replication_group_arn" {
  description = "The ARN of the ElastiCache Redis replication group"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].arn : null
}

output "redis_primary_endpoint_address" {
  description = "The address of the primary endpoint for the Redis replication group"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].primary_endpoint_address : null
}

output "redis_reader_endpoint_address" {
  description = "The address of the reader endpoint for the Redis replication group"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].reader_endpoint_address : null
}

output "redis_configuration_endpoint_address" {
  description = "The address of the configuration endpoint for the Redis replication group"
  value       = var.engine == "redis" ? aws_elasticache_replication_group.redis[0].configuration_endpoint_address : null
}

output "memcached_cluster_id" {
  description = "The ID of the ElastiCache Memcached cluster"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].cluster_id : null
}

output "memcached_cluster_address" {
  description = "The DNS name of the cache cluster without the port appended"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].cluster_address : null
}

output "memcached_configuration_endpoint" {
  description = "The configuration endpoint to allow host discovery"
  value       = var.engine == "memcached" ? aws_elasticache_cluster.memcached[0].configuration_endpoint : null
}

output "subnet_group_name" {
  description = "The name of the ElastiCache subnet group"
  value       = aws_elasticache_subnet_group.main.name
}

output "parameter_group_id" {
  description = "The ElastiCache parameter group name"
  value       = var.create_parameter_group ? aws_elasticache_parameter_group.main[0].id : null
}

output "security_group_id" {
  description = "The ID of the ElastiCache security group"
  value       = aws_security_group.elasticache.id
}

output "port" {
  description = "The port number on which the cache accepts connections"
  value       = var.port
}