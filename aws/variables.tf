# -----------------------------
# General
# -----------------------------
variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "virtuoso"
}

# -----------------------------
# VPC / Networking
# -----------------------------
variable "create_vpc" {
  description = "Set to true to create a new VPC, or false to use an existing one"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the new VPC (only used when create_vpc = true)"
  type        = string
  default     = "192.168.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (only used when create_vpc = true). Provide at least 2 for ALB."
  type        = list(string)
  default     = ["192.168.0.0/24", "192.168.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (only used when create_vpc = true). Provide at least 2."
  type        = list(string)
  default     = ["192.168.128.0/24", "192.168.129.0/24"]
}

variable "existing_vpc_id" {
  description = "ID of an existing VPC to deploy into (only used when create_vpc = false)"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "List of existing public subnet IDs for the ALB (only used when create_vpc = false). Must span at least 2 AZs."
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "List of existing private subnet IDs for ECS tasks and EFS (only used when create_vpc = false)"
  type        = list(string)
  default     = []
}

variable "web_allowed_cidrs" {
  description = "CIDR ranges allowed to reach Virtuoso HTTP and HTTPS endpoints. Set explicitly; 0.0.0.0/0 exposes the web interface publicly."
  type        = list(string)
  default     = ["127.0.0.1/32"]
}

variable "dba_secret_recovery_window_in_days" {
  description = "Secrets Manager recovery window for the DBA password. Use 7-30 in production; set 0 only for disposable test deployments."
  type        = number
  default     = 7

  validation {
    condition     = var.dba_secret_recovery_window_in_days == 0 || (var.dba_secret_recovery_window_in_days >= 7 && var.dba_secret_recovery_window_in_days <= 30)
    error_message = "dba_secret_recovery_window_in_days must be 0 or between 7 and 30."
  }
}

variable "expose_sql_endpoint" {
  description = "Expose Virtuoso SQL/ODBC/JDBC secure SQL/ODBC/JDBC port 1112 publicly through the NLB."
  type        = bool
  default     = false
}

variable "sql_allowed_cidrs" {
  description = "CIDR ranges allowed to reach the public Virtuoso secure SQL endpoint when expose_sql_endpoint=true."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.expose_sql_endpoint || length(var.sql_allowed_cidrs) > 0
    error_message = "sql_allowed_cidrs must contain at least one CIDR when expose_sql_endpoint=true."
  }
}

# -----------------------------
# EFS
# -----------------------------
variable "efs_throughput_mode" {
  description = "EFS throughput mode: bursting or elastic"
  type        = string
  default     = "bursting"
}

# -----------------------------
# ECS / Virtuoso Container
# -----------------------------
variable "virtuoso_image" {
  description = "Virtuoso container image name (openlink/virtuoso-opensource-7 or openlink/virtuoso-closedsource-8)"
  type        = string
  # No default - must be specified in terraform.tfvars or via deploy.sh
}

variable "virtuoso_image_tag" {
  description = "Virtuoso container image tag"
  type        = string
  # No default - must be specified in terraform.tfvars or via deploy.sh
}

variable "virtuoso_number_of_buffers" {
  description = "Virtuoso NumberOfBuffers setting. Percentage values such as 60% are resolved by the Virtuoso image against available container memory."
  type        = string
  default     = "60%"
}

variable "virtuoso_max_dirty_buffers" {
  description = "Virtuoso MaxDirtyBuffers setting. Percentage values such as 45% are resolved by the Virtuoso image against available container memory."
  type        = string
  default     = "45%"
}

variable "virtuoso_license_file" {
  description = "Path to Virtuoso license file (required for closedsource image, ignored for opensource)"
  type        = string
  default     = ""
}

variable "ecs_cpu" {
  description = <<-EOT
    CPU units for the ECS Fargate task. Valid values: 256, 512, 1024, 2048, 4096, 8192, 16384.

    Valid CPU/Memory combinations (Fargate):
    ┌─────────┬────────────────────────────────────────────────────────┐
    │ CPU     │ Memory (MiB)                                           │
    ├─────────┼────────────────────────────────────────────────────────┤
    │ 256     │ 512, 1024, 2048                                        │
    │ 512     │ 1024, 2048, 3072, 4096                                 │
    │ 1024    │ 2048, 3072, 4096, 5120, 6144, 7168, 8192               │
    │ 2048    │ 4096, 5120, 6144, 7168, 8192, ..., 16384 (1GB steps)   │
    │ 4096    │ 8192, 9216, ..., 30720 (1GB steps)                     │
    │ 8192    │ 16384, 20480, 24576, ..., 61440 (4GB steps)            │
    │ 16384   │ 32768, 40960, 49152, ..., 122880 (8GB steps)           │
    └─────────┴────────────────────────────────────────────────────────┘
  EOT
  type        = string
  # No default - must be specified in terraform.tfvars or via deploy.sh

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096", "8192", "16384"], var.ecs_cpu)
    error_message = "ecs_cpu must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384"
  }
}

variable "ecs_memory" {
  description = <<-EOT
    Memory (MiB) for the ECS Fargate task. Must be a valid combination with ecs_cpu.

    Common configurations:
    - Development/Testing: CPU=512, Memory=1024 (0.5 vCPU, 1 GB)
    - Small Production:    CPU=1024, Memory=2048 (1 vCPU, 2 GB)
    - Medium Production:   CPU=2048, Memory=4096 (2 vCPU, 4 GB)
    - Large Production:    CPU=4096, Memory=8192 (4 vCPU, 8 GB)
    - Heavy Workloads:     CPU=8192, Memory=16384 (8 vCPU, 16 GB)
  EOT
  type        = string
  # No default - must be specified in terraform.tfvars or via deploy.sh
}

# -----------------------------
# Logging
# -----------------------------
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}


# -----------------------------
# Backup / Recovery
# -----------------------------
variable "backup_sync_image" {
  description = "AWS CLI image used by the on-demand ECS backup sync task."
  type        = string
  default     = "public.ecr.aws/aws-cli/aws-cli:2.15.0"
}

variable "backup_bucket_versioning" {
  description = "Enable S3 versioning for the Virtuoso backup bucket."
  type        = bool
  default     = true
}

variable "backup_bucket_force_destroy" {
  description = "Allow Terraform destroy to remove the backup bucket and all objects. Keep false for production."
  type        = bool
  default     = false
}


variable "enable_backup_sync_schedule" {
  description = "Create a provider-native daily schedule to sync Virtuoso backup files to durable object storage. Recommended for production."
  type        = bool
  default     = false
}

variable "backup_sync_schedule_expression" {
  description = "AWS EventBridge schedule expression for backup file sync, for example rate(1 day) or cron(30 3 * * ? *)."
  type        = string
  default     = "rate(1 day)"
}
