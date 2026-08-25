# -----------------------------
# EFS for persistent Virtuoso storage
# -----------------------------
resource "aws_efs_file_system" "this" {
  creation_token  = "${var.project_name}-efs"
  throughput_mode = var.efs_throughput_mode
  encrypted       = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = { Name = "${var.project_name}-efs" }
}

resource "aws_efs_mount_target" "this" {
  count           = length(local.private_subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = local.private_subnet_ids[count.index]
  security_groups = [aws_security_group.ecs.id]
}
