# The file storage bucket was created outside Terraform. These resources only
# manage its security settings. Each one REPLACES the bucket's existing
# setting of that kind (policy, lifecycle rules, logging), so check the live
# bucket before the first apply (see README).

data "aws_s3_bucket" "filestorage" {
  bucket = "brokerone-dev-filestorage"
}

resource "aws_s3_bucket_policy" "filestorage" {
  bucket = data.aws_s3_bucket.filestorage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          data.aws_s3_bucket.filestorage.arn,
          "${data.aws_s3_bucket.filestorage.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_versioning" "filestorage" {
  bucket = data.aws_s3_bucket.filestorage.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "filestorage" {
  bucket = data.aws_s3_bucket.filestorage.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.filestorage]
}

resource "aws_s3_bucket_logging" "filestorage" {
  bucket        = data.aws_s3_bucket.filestorage.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access/brokerone-dev-filestorage/"

  depends_on = [aws_s3_bucket_policy.logs]
}
