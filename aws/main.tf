# -----------------------------
# Virtuoso on AWS - Root Configuration
# -----------------------------
# This file calls the virtuoso-server module.
# Users can deploy directly with: tofu apply or ./deploy.sh
# The module can also be called programmatically for SaaS deployments.

provider "aws" {
  region = var.region
}

# -----------------------------
# Virtuoso Server Module
# -----------------------------
module "virtuoso" {
  source = "./modules/virtuoso-server"

  # General
  region       = var.region
  project_name = var.project_name

  # VPC / Networking
  create_vpc                         = var.create_vpc
  vpc_cidr                           = var.vpc_cidr
  public_subnet_cidrs                = var.public_subnet_cidrs
  private_subnet_cidrs               = var.private_subnet_cidrs
  existing_vpc_id                    = var.existing_vpc_id
  existing_public_subnet_ids         = var.existing_public_subnet_ids
  existing_private_subnet_ids        = var.existing_private_subnet_ids
  web_allowed_cidrs                  = var.web_allowed_cidrs
  expose_sql_endpoint                = var.expose_sql_endpoint
  sql_allowed_cidrs                  = var.sql_allowed_cidrs
  dba_secret_recovery_window_in_days = var.dba_secret_recovery_window_in_days

  # EFS
  efs_throughput_mode = var.efs_throughput_mode

  # ECS / Virtuoso Container
  virtuoso_image             = var.virtuoso_image
  virtuoso_image_tag         = var.virtuoso_image_tag
  virtuoso_number_of_buffers = var.virtuoso_number_of_buffers
  virtuoso_max_dirty_buffers = var.virtuoso_max_dirty_buffers
  ecs_cpu                    = var.ecs_cpu
  ecs_memory                 = var.ecs_memory

  # Backup / Recovery
  backup_sync_image               = var.backup_sync_image
  backup_bucket_versioning        = var.backup_bucket_versioning
  backup_bucket_force_destroy     = var.backup_bucket_force_destroy
  enable_backup_sync_schedule     = var.enable_backup_sync_schedule
  backup_sync_schedule_expression = var.backup_sync_schedule_expression

  # Logging
  log_retention_days = var.log_retention_days
}
