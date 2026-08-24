# -----------------------------
# Provider-native scheduled backup sync
# -----------------------------
data "aws_iam_policy_document" "backup_sync_events_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "backup_sync_events" {
  count              = var.enable_backup_sync_schedule ? 1 : 0
  name               = "${var.project_name}-backup-sync-events"
  assume_role_policy = data.aws_iam_policy_document.backup_sync_events_assume_role.json
  tags               = { Name = "${var.project_name}-backup-sync-events" }
}

data "aws_iam_policy_document" "backup_sync_events" {
  statement {
    effect = "Allow"
    actions = [
      "ecs:RunTask"
    ]
    resources = [aws_ecs_task_definition.backup_sync.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.ecs_execution.arn,
      aws_iam_role.ecs_task.arn
    ]
  }
}

resource "aws_iam_role_policy" "backup_sync_events" {
  count  = var.enable_backup_sync_schedule ? 1 : 0
  name   = "${var.project_name}-backup-sync-events"
  role   = aws_iam_role.backup_sync_events[0].id
  policy = data.aws_iam_policy_document.backup_sync_events.json
}

resource "aws_cloudwatch_event_rule" "backup_sync" {
  count               = var.enable_backup_sync_schedule ? 1 : 0
  name                = "${var.project_name}-backup-sync"
  description         = "Sync Virtuoso online backup files from EFS to S3"
  schedule_expression = var.backup_sync_schedule_expression
  tags                = { Name = "${var.project_name}-backup-sync" }
}

resource "aws_cloudwatch_event_target" "backup_sync" {
  count     = var.enable_backup_sync_schedule ? 1 : 0
  rule      = aws_cloudwatch_event_rule.backup_sync[0].name
  target_id = "${var.project_name}-backup-sync"
  arn       = aws_ecs_cluster.this.arn
  role_arn  = aws_iam_role.backup_sync_events[0].arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.backup_sync.arn
    task_count          = 1
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = local.private_subnet_ids
      security_groups  = [aws_security_group.ecs.id]
      assign_public_ip = false
    }
  }
}
