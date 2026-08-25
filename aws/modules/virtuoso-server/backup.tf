# -----------------------------
# Durable backup storage
# -----------------------------
resource "random_id" "backup_bucket" {
  byte_length = 4
}

resource "aws_s3_bucket" "backups" {
  bucket        = lower("${var.project_name}-backups-${random_id.backup_bucket.hex}")
  force_destroy = var.backup_bucket_force_destroy

  tags = {
    Name    = "${var.project_name}-backups"
    Purpose = "Virtuoso online backups"
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket                  = aws_s3_bucket.backups.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    # Preserve AWS's SSE-C prohibition so backup objects cannot be encrypted
    # with a customer-supplied key that the deployment cannot recover.
    bucket_key_enabled       = false
    blocked_encryption_types = ["SSE-C"]

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = var.backup_bucket_versioning ? "Enabled" : "Suspended"
  }
}
