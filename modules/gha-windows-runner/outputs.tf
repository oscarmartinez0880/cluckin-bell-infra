output "instance_id" {
  value = aws_instance.runner.id
}

output "public_ip" {
  value = aws_instance.runner.public_ip
}

output "iam_role_arn" {
  value = aws_iam_role.runner.arn
}

output "security_group_id" {
  value = aws_security_group.runner.id
}