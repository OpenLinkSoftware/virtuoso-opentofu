# -----------------------------
# Virtuoso Server Module - Data Sources
# -----------------------------

data "aws_availability_zones" "available" {}

data "aws_kms_key" "efs" {
  key_id = "alias/aws/elasticfilesystem"
}
