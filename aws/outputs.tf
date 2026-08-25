# -----------------------------
# Virtuoso on AWS - Outputs
# -----------------------------

output "region" {
  description = "AWS region used by this deployment."
  value       = var.region
}
# These outputs reference the virtuoso-server module.

output "virtuoso_dns_name" {
  description = "Virtuoso DNS name (NLB)"
  value       = module.virtuoso.virtuoso_dns_name
}

output "virtuoso_http_url" {
  description = "URL to access Virtuoso HTTP (Conductor, SPARQL)"
  value       = module.virtuoso.virtuoso_http_url
}

output "virtuoso_https_url" {
  description = "URL to access Virtuoso HTTPS"
  value       = module.virtuoso.virtuoso_https_url
}

output "virtuoso_sql_endpoint" {
  description = "Virtuoso SQL endpoint (ODBC/JDBC)"
  value       = module.virtuoso.virtuoso_sql_endpoint
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.virtuoso.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.virtuoso.ecs_service_name
}

output "vpc_id" {
  description = "VPC ID in use"
  value       = module.virtuoso.vpc_id
}

output "secret_name" {
  description = "Secrets Manager secret name for the DBA password. Retrieve with: aws secretsmanager get-secret-value --secret-id $(tofu output -raw secret_name)"
  value       = module.virtuoso.secret_name
}

output "secret_arn" {
  description = "Secrets Manager ARN for the DBA password. Note: retrieve by secret_name for this deployment helper output."
  value       = module.virtuoso.secret_arn
}

output "virtuoso_database_path" {
  description = "Container path where Virtuoso database is stored (EFS mount point)"
  value       = module.virtuoso.virtuoso_database_path
}


output "backup_bucket_name" {
  description = "S3 bucket used for durable Virtuoso online backup copies."
  value       = module.virtuoso.backup_bucket_name
}

output "backup_s3_uri" {
  description = "S3 URI prefix used for Virtuoso online backup copies."
  value       = module.virtuoso.backup_s3_uri
}

output "backup_sync_task_definition_arn" {
  description = "ECS task definition ARN used to sync EFS backup files to or from S3."
  value       = module.virtuoso.backup_sync_task_definition_arn
}


output "private_subnet_ids" {
  description = "Private subnet IDs used by ECS and backup sync tasks."
  value       = module.virtuoso.private_subnet_ids
}

output "security_group_id" {
  description = "Security group ID used by ECS and backup sync tasks."
  value       = module.virtuoso.security_group_id
}


output "restore_task_definition_arn" {
  description = "ECS task definition ARN used to restore Virtuoso from staged online backup files."
  value       = module.virtuoso.restore_task_definition_arn
}


output "backup_sync_schedule_name" {
  description = "AWS EventBridge rule name for scheduled backup sync, or null when disabled."
  value       = module.virtuoso.backup_sync_schedule_name
}
