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

# No lifecycle rules: AWS does not allow lifecycle configuration on a bucket
# with MFA Delete (Scrut: "Bucket without MFA Delete"). Old versions are kept
# until removed manually by the root user with MFA. MFA Delete itself is
# enabled by the root user via CLI, not by Terraform.

resource "aws_s3_bucket_logging" "filestorage" {
  bucket        = data.aws_s3_bucket.filestorage.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access/brokerone-dev-filestorage/"

  depends_on = [aws_s3_bucket_policy.logs]
}
