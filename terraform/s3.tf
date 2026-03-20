# =============================================================================
# s3.tf — S3 buckets
# =============================================================================
# Two buckets:
#   1. Database backup bucket (intentionally PUBLIC — weakness #5)
#   2. CloudTrail log bucket (private — for audit logging)

# =============================================================================
# BUCKET 1: Database backups (PUBLIC — intentional weakness)
# =============================================================================
resource "aws_s3_bucket" "db_backups" {
  bucket        = "wiz-exercise-db-backups-${random_id.suffix.hex}"
  force_destroy = true   # Allow Terraform to delete bucket even if it has files

  tags = {
    Project = "wiz-exercise"
    Purpose = "MongoDB backups"
  }
}

# Disable ALL public access protections (intentional weakness #5)
# AWS enables these by default to prevent accidental public exposure.
# We're deliberately disabling every safety net.
resource "aws_s3_bucket_public_access_block" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy granting public read + list to everyone
resource "aws_s3_bucket_policy" "db_backups_public" {
  bucket = aws_s3_bucket.db_backups.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadAndList"
      Effect    = "Allow"
      Principal = "*"             # Everyone on the internet
      Action = [
        "s3:GetObject",           # Download individual files
        "s3:ListBucket"           # List all files in the bucket
      ]
      Resource = [
        aws_s3_bucket.db_backups.arn,        # Bucket itself (for ListBucket)
        "${aws_s3_bucket.db_backups.arn}/*"   # All objects (for GetObject)
      ]
    }]
  })

  # Must wait for the public access block to be disabled first,
  # otherwise AWS rejects the public policy
  depends_on = [aws_s3_bucket_public_access_block.db_backups]
}

# =============================================================================
# BUCKET 2: CloudTrail logs (private — security control)
# =============================================================================
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "wiz-exercise-cloudtrail-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Project = "wiz-exercise"
    Purpose = "CloudTrail audit logs"
  }
}

# CloudTrail needs explicit permission to write to this bucket
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
