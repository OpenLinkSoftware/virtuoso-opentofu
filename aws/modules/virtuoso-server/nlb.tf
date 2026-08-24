# -----------------------------
# Network Load Balancer
# -----------------------------
# Single NLB handles all Virtuoso ports:
#   - Port 80   → Container 8890 (HTTP)
#   - Port 443  → Container 8891 (HTTPS, Virtuoso's built-in SSL)
#   - Port 1112 → Container 1112 (secure SQL/ODBC/JDBC)

resource "aws_lb" "this" {
  name               = "${var.project_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = local.public_subnet_ids
  tags               = { Name = "${var.project_name}-nlb" }
}

# -----------------------------
# Target Group - HTTP (Port 80 → 8890)
# -----------------------------
resource "aws_lb_target_group" "http" {
  name        = "${var.project_name}-http-tg"
  port        = 8890
  protocol    = "TCP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    port                = 8890
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "${var.project_name}-http-tg" }
}

# -----------------------------
# Target Group - HTTPS (Port 443 → 8891)
# -----------------------------
resource "aws_lb_target_group" "https" {
  name        = "${var.project_name}-https-tg"
  port        = 8891
  protocol    = "TCP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    port                = 8891
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "${var.project_name}-https-tg" }
}

# -----------------------------
# Target Group - Secure SQL (Port 1112 → 1112)
# -----------------------------
resource "aws_lb_target_group" "sql" {
  count       = var.expose_sql_endpoint ? 1 : 0
  name        = "${var.project_name}-sql-tg"
  port        = 1112
  protocol    = "TCP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    port                = 1112
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "${var.project_name}-sql-tg" }
}

# -----------------------------
# NLB Listener - HTTP (Port 80)
# -----------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }

  tags = { Name = "${var.project_name}-http-listener" }
}

# -----------------------------
# NLB Listener - HTTPS (Port 443)
# -----------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }

  tags = { Name = "${var.project_name}-https-listener" }
}

# -----------------------------
# NLB Listener - Secure SQL (Port 1112)
# -----------------------------
resource "aws_lb_listener" "sql" {
  count             = var.expose_sql_endpoint ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 1112
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sql[0].arn
  }

  tags = { Name = "${var.project_name}-sql-listener" }
}
