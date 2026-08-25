# -----------------------------
# Virtuoso Server Module - Outputs
# -----------------------------

output "virtuoso_dns_name" {
  description = "Virtuoso DNS name (NLB)"
  value       = aws_lb.this.dns_name
}

output "virtuoso_http_url" {
  description = "URL to access Virtuoso HTTP (Conductor, SPARQL)"
  value       = "http://${aws_lb.this.dns_name}"
}

output "virtuoso_https_url" {
  description = "URL to access Virtuoso HTTPS"
  value       = "https://${aws_lb.this.dns_name}"
}

output "virtuoso_sql_endpoint" {
  description = "Virtuoso secure SQL endpoint (ODBC/JDBC), or null when public SQL exposure is disabled."
  value       = var.expose_sql_endpoint ? "${aws_lb.this.dns_name}:1112" : null
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "vpc_id" {
  description = "VPC ID in use"
  value       = local.vpc_id
}

output "secret_name" {
  description = "Secrets Manager secret name for the DBA password"
  value       = aws_secretsmanager_secret.dba_password.name
}

output "secret_arn" {
  description = "Secrets Manager ARN for the DBA password"
  value       = aws_secretsmanager_secret.dba_password.arn
}

output "virtuoso_database_path" {
  description = "Container path where Virtuoso database is stored (EFS mount point)"
  value       = local.virtuoso_database_path
}

# Additional outputs useful for SaaS control plane
output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.this.arn
}

output "ecs_service_arn" {
  description = "ECS service ARN"
  value       = aws_ecs_service.this.id
}

output "efs_file_system_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.this.id
}

output "nlb_arn" {
  description = "Network Load Balancer ARN"
  value       = aws_lb.this.arn
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by ECS"
  value       = local.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by NLB"
  value       = local.public_subnet_ids
}

output "security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs.id
}

output "backup_bucket_name" {
  description = "S3 bucket used for durable Virtuoso online backup copies."
  value       = aws_s3_bucket.backups.bucket
}

output "backup_s3_uri" {
  description = "S3 URI prefix used for Virtuoso online backup copies."
  value       = "s3://${aws_s3_bucket.backups.bucket}/online/"
}

output "backup_sync_task_definition_arn" {
  description = "ECS task definition ARN used to sync EFS backup files to or from S3."
  value       = aws_ecs_task_definition.backup_sync.arn
}


output "restore_task_definition_arn" {
  description = "ECS task definition ARN used to restore Virtuoso from staged online backup files."
  value       = aws_ecs_task_definition.restore.arn
}


output "backup_sync_schedule_name" {
  description = "AWS EventBridge rule name for scheduled backup sync, or null when disabled."
  value       = var.enable_backup_sync_schedule ? aws_cloudwatch_event_rule.backup_sync[0].name : null
}
