data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ec2" {
  name = "brokerone-dev-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Role permissions are customer-managed policies rather than inline policies
# (Scrut: "IAM role with inline policies").

resource "aws_iam_policy" "codecommit_read" {
  name = "brokerone-dev-codecommit-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPull",
          "codecommit:GetRepository"
        ]
        Resource = "arn:aws:codecommit:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.codecommit_repo_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codecommit_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.codecommit_read.arn
}

resource "aws_iam_policy" "cloudwatch_logs" {
  name = "brokerone-dev-cloudwatch-logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.brokerone_app.arn,
          "${aws_cloudwatch_log_group.brokerone_app.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

resource "aws_iam_policy" "pipeline_artifacts_read" {
  name = "brokerone-dev-pipeline-artifacts-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::codepipeline-ap-south-1-9d1e1f92dca8-4f3f-93a0-4fd30a04c69a/BrokerOne-Dev-Pipeli/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "pipeline_artifacts_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.pipeline_artifacts_read.arn
}

resource "aws_iam_instance_profile" "ec2" {
  name = "brokerone-dev-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_iam_policy" "filestorage_rw" {
  name = "brokerone-dev-filestorage"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FileStorageObjects"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "${data.aws_s3_bucket.filestorage.arn}/*"
      },
      {
        Sid      = "FileStorageList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = data.aws_s3_bucket.filestorage.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "filestorage_rw" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.filestorage_rw.arn
}

resource "aws_iam_policy" "ses_send" {
  name = "brokerone-dev-ses-send"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SesSendEmail"
        Effect   = "Allow"
        Action   = ["ses:SendEmail", "ses:SendRawEmail"]
        Resource = "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ses_send" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.ses_send.arn
}
