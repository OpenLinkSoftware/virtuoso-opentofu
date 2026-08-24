# -----------------------------
# Locals
# -----------------------------
locals {
  # Determine database path based on image type
  # closedsource-8 uses /opt/virtuoso/database
  # opensource-7 uses /opt/virtuoso-opensource/database
  is_closedsource        = can(regex("closedsource", var.virtuoso_image))
  virtuoso_database_path = local.is_closedsource ? "/opt/virtuoso/database" : "/opt/virtuoso-opensource/database"
}

# -----------------------------
# CloudWatch Log Group
# -----------------------------
resource "aws_cloudwatch_log_group" "virtuoso" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days
  tags              = { Name = "${var.project_name}-logs" }
}

# -----------------------------
# ECS Cluster
# -----------------------------
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
  tags = { Name = "${var.project_name}-cluster" }
}

# -----------------------------
# ECS Task Definition
# -----------------------------
resource "aws_ecs_task_definition" "virtuoso" {
  family                   = var.project_name
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "virtuoso"
    image     = "${var.virtuoso_image}:${var.virtuoso_image_tag}"
    essential = true

    entryPoint = ["/bin/sh", "-c"]
    command = [join(" && ", [
      "rm -f ${local.virtuoso_database_path}/*.lck ${local.virtuoso_database_path}/*.db.lock 2>/dev/null || true",
      "echo 'Cleaned lock files'",
      "cd ${local.virtuoso_database_path}",
      "if [ -f virtuoso.ini ]; then $VIRTUOSO_HOME/bin/inifile +inifile virtuoso.ini +section Parameters +key NumberOfBuffers +value \"$VIRT_PARAMETERS_NumberOfBuffers\" && $VIRTUOSO_HOME/bin/inifile +inifile virtuoso.ini +section Parameters +key MaxDirtyBuffers +value \"$VIRT_PARAMETERS_MaxDirtyBuffers\" && echo \"Applied memory settings: NumberOfBuffers=$VIRT_PARAMETERS_NumberOfBuffers MaxDirtyBuffers=$VIRT_PARAMETERS_MaxDirtyBuffers\"; fi",
      "exec /virtuoso-entrypoint.sh start"
    ])]

    portMappings = [
      {
        containerPort = 8890
        hostPort      = 8890
        protocol      = "tcp"
      },
      {
        containerPort = 1112
        hostPort      = 1112
        protocol      = "tcp"
      },
      {
        containerPort = 8891
        hostPort      = 8891
        protocol      = "tcp"
      }
    ]

    environment = [
      {
        name  = "VIRT_PARAMETERS_NumberOfBuffers"
        value = var.virtuoso_number_of_buffers
      },
      {
        name  = "VIRT_PARAMETERS_MaxDirtyBuffers"
        value = var.virtuoso_max_dirty_buffers
      }
    ]

    secrets = [
      {
        name      = "DBA_PASSWORD"
        valueFrom = aws_secretsmanager_secret.dba_password.arn
      }
    ]

    mountPoints = [
      {
        sourceVolume  = "efs-vol"
        containerPath = local.virtuoso_database_path
        readOnly      = false
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.virtuoso.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "ecs"
      }
    }
  }])

  volume {
    name = "efs-vol"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"
      root_directory     = "/"
    }
  }

  tags = { Name = "${var.project_name}-task" }
}

# -----------------------------
# ECS Backup Sync Task Definition
# -----------------------------
resource "aws_ecs_task_definition" "backup_sync" {
  family                   = "${var.project_name}-backup-sync"
  cpu                      = "512"
  memory                   = "1024"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "backup-sync"
    image     = var.backup_sync_image
    essential = true
    command = [
      "s3",
      "sync",
      "${local.virtuoso_database_path}/backup",
      "s3://${aws_s3_bucket.backups.bucket}/online/",
      "--exclude",
      "*",
      "--include",
      "virtuoso_#*.bp"
    ]

    mountPoints = [
      {
        sourceVolume  = "efs-vol"
        containerPath = local.virtuoso_database_path
        readOnly      = false
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.virtuoso.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "backup-sync"
      }
    }
  }])

  volume {
    name = "efs-vol"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"
      root_directory     = "/"
    }
  }

  tags = { Name = "${var.project_name}-backup-sync-task" }
}

# -----------------------------
# ECS Restore Task Definition
# -----------------------------
resource "aws_ecs_task_definition" "restore" {
  family                   = "${var.project_name}-restore"
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "virtuoso-restore"
    image     = "${var.virtuoso_image}:${var.virtuoso_image_tag}"
    essential = true
    command = [
      "/bin/bash",
      "-lc",
      "set -euo pipefail; cd ${local.virtuoso_database_path}; restore_dir=restore-pre-$(date -u +%Y%m%dT%H%M%SZ); mkdir -p $restore_dir; for f in virtuoso.db virtuoso.log virtuoso.trx virtuoso-temp.db virtuoso.pxa virtuoso.lck; do if [ -e $f ]; then mv $f $restore_dir/; fi; done; server=$(command -v virtuoso-t || command -v virtuoso-iodbc-t || find / -name virtuoso-t -o -name virtuoso-iodbc-t 2>/dev/null | head -1); if [ -z $server ]; then echo Virtuoso server binary not found; exit 1; fi; exec $server +foreground +configfile virtuoso.ini +restore-backup backup/virtuoso_#"
    ]

    mountPoints = [
      {
        sourceVolume  = "efs-vol"
        containerPath = local.virtuoso_database_path
        readOnly      = false
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.virtuoso.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "restore"
      }
    }
  }])

  volume {
    name = "efs-vol"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.this.id
      transit_encryption = "ENABLED"
      root_directory     = "/"
    }
  }

  tags = { Name = "${var.project_name}-restore-task" }
}

# -----------------------------
# ECS Service
# -----------------------------
resource "aws_ecs_service" "this" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.virtuoso.arn
  launch_type     = "FARGATE"
  desired_count   = 1 # Single instance only - Virtuoso uses file locking

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  # HTTP (NLB port 80 → container 8890)
  load_balancer {
    target_group_arn = aws_lb_target_group.http.arn
    container_name   = "virtuoso"
    container_port   = 8890
  }

  # HTTPS (NLB port 443 → container 8891)
  load_balancer {
    target_group_arn = aws_lb_target_group.https.arn
    container_name   = "virtuoso"
    container_port   = 8891
  }

  dynamic "load_balancer" {
    for_each = var.expose_sql_endpoint ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.sql[0].arn
      container_name   = "virtuoso"
      container_port   = 1112
    }
  }

  enable_execute_command = true
  depends_on             = [aws_lb_listener.http, aws_lb_listener.https]

  tags = { Name = "${var.project_name}-service" }
}
