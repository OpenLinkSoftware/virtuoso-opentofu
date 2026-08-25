# -----------------------------
# DBA Password – Secrets Manager
# -----------------------------
resource "random_password" "dba" {
  length           = 20
  special          = true
  override_special = "-_"
}

resource "aws_secretsmanager_secret" "dba_password" {
  name                    = "${var.project_name}-dba-password"
  description             = "Virtuoso DBA password for ${var.project_name}"
  recovery_window_in_days = var.dba_secret_recovery_window_in_days
  tags                    = { Name = "${var.project_name}-dba-password" }
}

resource "aws_secretsmanager_secret_version" "dba_password" {
  secret_id     = aws_secretsmanager_secret.dba_password.id
  secret_string = random_password.dba.result
}
