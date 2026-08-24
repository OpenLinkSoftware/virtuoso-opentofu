# -----------------------------
# Locals – resolve effective IDs
# -----------------------------
locals {
  vpc_id             = var.create_vpc ? aws_vpc.this[0].id : var.existing_vpc_id
  public_subnet_ids  = var.create_vpc ? aws_subnet.public[*].id : var.existing_public_subnet_ids
  private_subnet_ids = var.create_vpc ? aws_subnet.private[*].id : var.existing_private_subnet_ids
}

# -----------------------------
# VPC (created only when create_vpc = true)
# -----------------------------
resource "aws_vpc" "this" {
  count                = var.create_vpc ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = { Name = "${var.project_name}-igw" }
}

# -----------------------------
# Subnets (created only when create_vpc = true)
# -----------------------------
resource "aws_subnet" "public" {
  count                   = var.create_vpc ? length(var.public_subnet_cidrs) : 0
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  tags                    = { Name = "${var.project_name}-public-${count.index}" }
}

resource "aws_subnet" "private" {
  count                   = var.create_vpc ? length(var.private_subnet_cidrs) : 0
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = var.private_subnet_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  tags                    = { Name = "${var.project_name}-private-${count.index}" }
}

# -----------------------------
# Public Route Table + IGW Route
# -----------------------------
resource "aws_route_table" "public" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.create_vpc ? length(var.public_subnet_cidrs) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# -----------------------------
# NAT Gateway for Private Subnets
# -----------------------------
resource "aws_eip" "nat" {
  count  = var.create_vpc ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  count         = var.create_vpc ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.project_name}-nat" }
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  count  = var.create_vpc ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[0].id
  }
  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = var.create_vpc ? length(var.private_subnet_cidrs) : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# -----------------------------
# Security Group - ECS Tasks
# -----------------------------
# NLB does not use security groups - it preserves client IPs
# So we allow traffic from anywhere on the exposed ports

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "ECS tasks"
  vpc_id      = local.vpc_id

  # Allow Virtuoso HTTP (NLB port 80 → container 8890)
  ingress {
    description = "Virtuoso HTTP"
    from_port   = 8890
    to_port     = 8890
    protocol    = "tcp"
    cidr_blocks = var.web_allowed_cidrs
  }

  # Allow Virtuoso HTTPS (NLB port 443 → container 8891)
  ingress {
    description = "Virtuoso HTTPS"
    from_port   = 8891
    to_port     = 8891
    protocol    = "tcp"
    cidr_blocks = var.web_allowed_cidrs
  }

  dynamic "ingress" {
    for_each = var.expose_sql_endpoint ? [1] : []
    content {
      description = "Virtuoso Secure SQL"
      from_port   = 1112
      to_port     = 1112
      protocol    = "tcp"
      cidr_blocks = var.sql_allowed_cidrs
    }
  }

  # Allow NFS for EFS mounts (self-referencing)
  ingress {
    description = "NFS for EFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-sg" }
}
