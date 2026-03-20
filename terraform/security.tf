# =============================================================================
# security.tf — Cloud Native Security Controls (mandatory section)
# =============================================================================

# -----------------------------------------------------------------------------
# AUDIT: AWS CloudTrail
# -----------------------------------------------------------------------------
# Records every API call in the account — the foundation for forensics
resource "aws_cloudtrail" "main" {
  name                          = "wiz-exercise-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true    # Capture IAM events (global service)
  is_multi_region_trail         = true    # All regions — prevents blind spots
  enable_logging                = true

  # Also log S3 data events for the backup bucket
  # This tracks who downloads files — important for the public bucket
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.db_backups.arn}/"]
    }
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]

  tags = { Project = "wiz-exercise" }
}

# -----------------------------------------------------------------------------
# PREVENTATIVE: Require IMDSv2 on all EC2 instances
# -----------------------------------------------------------------------------
# Blocks SSRF-based credential theft from the Instance Metadata Service.
# This is the technique used in the 2019 Capital One breach.
resource "aws_ec2_instance_metadata_defaults" "imdsv2" {
  http_tokens = "required"   # Forces IMDSv2 — blocks IMDSv1 requests
}

# -----------------------------------------------------------------------------
# DETECTIVE: Amazon GuardDuty
# -----------------------------------------------------------------------------
# ML-based threat detection across CloudTrail, VPC Flow Logs, and DNS logs
data "aws_guardduty_detector" "existing" {}