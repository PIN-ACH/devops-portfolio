output "endpoint" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = var.db_name
}

output "security_group_id" {
  value = aws_security_group.db.id
}

output "secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}
