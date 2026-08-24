# -----------------------------
# Virtuoso Server Module - Variables
# -----------------------------

# -----------------------------
# General
# -----------------------------
variable "region" {
  description = "AWS region for CloudWatch logs"
  type        = string
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
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
  description = "CIDR blocks for public subnets (only used when create_vpc = true)"
  type        = list(string)
  default     = ["192.168.0.0/24", "192.168.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (only used when create_vpc = true)"
  type        = list(string)
  default     = ["192.168.128.0/24", "192.168.129.0/24"]
}

variable "existing_vpc_id" {
  description = "ID of an existing VPC to deploy into (only used when create_vpc = false)"
  type        = string
  default     = ""
}

variable "existing_public_subnet_ids" {
  description = "List of existing public subnet IDs (only used when create_vpc = false)"
  type        = list(string)
  default     = []
}

variable "existing_private_subnet_ids" {
  description = "List of existing private subnet IDs (only used when create_vpc = false)"
  type        = list(string)
  default     = []
}

variable "web_allowed_cidrs" {
  description = "CIDR ranges allowed to reach Virtuoso HTTP and HTTPS endpoints."
  type        = list(string)
  default     = ["0.0.0.0/0"]
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
  description = "Virtuoso container image name"
  type        = string
}

variable "virtuoso_image_tag" {
  description = "Virtuoso container image tag"
  type        = string
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

variable "ecs_cpu" {
  description = "CPU units for the ECS Fargate task"
  type        = string

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096", "8192", "16384"], var.ecs_cpu)
    error_message = "ecs_cpu must be one of: 256, 512, 1024, 2048, 4096, 8192, 16384"
  }
}

variable "ecs_memory" {
  description = "Memory (MiB) for the ECS Fargate task"
  type        = string
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
