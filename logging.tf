# Central log bucket for BrokerOne DEV: ALB access logs, S3 server access logs
# for the file storage bucket, and VPC flow logs.
# Encryption must stay SSE-S3 (AES256): ALB access logs do not support SSE-KMS.

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket" "logs" {
  bucket = "brokerone-dev-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "brokerone-dev-logs"
  }
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# No lifecycle rules: AWS does not allow lifecycle configuration on a bucket
# with MFA Delete (Scrut: "Bucket without MFA Delete"). Logs are kept until
# removed manually by the root user with MFA.

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "AlbAccessLogs"
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.main.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Sid       = "S3ServerAccessLogs"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/s3-access/*"
        Condition = {
          ArnLike      = { "aws:SourceArn" = data.aws_s3_bucket.filestorage.arn }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid       = "VpcFlowLogsWrite"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs.arn}/vpc-flow-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
          ArnLike = { "aws:SourceArn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*" }
        }
      },
      {
        Sid       = "VpcFlowLogsAclCheck"
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource  = aws_s3_bucket.logs.arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
          ArnLike      = { "aws:SourceArn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*" }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

# VPC-level flow logs cover every subnet in the BrokerOne VPC, including the
# pre-existing ones not managed here (brokerone-public-1a, brokerone-db-subnet-group*).
resource "aws_flow_log" "vpc" {
  vpc_id                   = var.vpc_id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = "${aws_s3_bucket.logs.arn}/vpc-flow-logs"
  max_aggregation_interval = 600

  tags = {
    Name = "brokerone-dev-vpc-flow-logs"
  }

  depends_on = [aws_s3_bucket_policy.logs]
}

# Receives server access logs for the main log bucket (Scrut: "S3 bucket
# logging" on brokerone-dev-logs). No lifecycle rule, so MFA Delete can be
# enabled on it as well.
resource "aws_s3_bucket" "logs_access" {
  bucket = "brokerone-dev-logs-access-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "brokerone-dev-logs-access"
  }
}

resource "aws_s3_bucket_ownership_controls" "logs_access" {
  bucket = aws_s3_bucket.logs_access.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs_access" {
  bucket = aws_s3_bucket.logs_access.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_access" {
  bucket = aws_s3_bucket.logs_access.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs_access" {
  bucket = aws_s3_bucket.logs_access.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "logs_access" {
  bucket = aws_s3_bucket.logs_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.logs_access.arn,
          "${aws_s3_bucket.logs_access.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "S3ServerAccessLogs"
        Effect    = "Allow"
        Principal = { Service = "logging.s3.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.logs_access.arn}/brokerone-dev-logs/*"
        Condition = {
          ArnLike      = { "aws:SourceArn" = aws_s3_bucket.logs.arn }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs_access]
}

resource "aws_s3_bucket_logging" "logs" {
  bucket        = aws_s3_bucket.logs.id
  target_bucket = aws_s3_bucket.logs_access.id
  target_prefix = "brokerone-dev-logs/"

  depends_on = [aws_s3_bucket_policy.logs_access]
}
