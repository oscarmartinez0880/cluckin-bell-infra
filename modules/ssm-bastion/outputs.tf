output "instance_id" {
  description = "ID of the bastion EC2 instance"
  value       = aws_instance.bastion.id
}

output "instance_arn" {
  description = "ARN of the bastion EC2 instance"
  value       = aws_instance.bastion.arn
}

output "security_group_id" {
  description = "ID of the bastion security group"
  value       = aws_security_group.bastion.id
}

output "iam_role_arn" {
  description = "ARN of the bastion IAM role"
  value       = aws_iam_role.bastion.arn
}

output "iam_role_name" {
  description = "Name of the bastion IAM role"
  value       = aws_iam_role.bastion.name
}

output "private_ip" {
  description = "Private IP address of the bastion instance"
  value       = aws_instance.bastion.private_ip
}