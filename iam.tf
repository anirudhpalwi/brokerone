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

resource "aws_iam_role_policy" "codecommit_read" {
  name = "brokerone-dev-codecommit-read"
  role = aws_iam_role.ec2.id

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

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "brokerone-dev-cloudwatch-logs"
  role = aws_iam_role.ec2.id

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

resource "aws_iam_role_policy" "pipeline_artifacts_read" {
  name = "brokerone-dev-pipeline-artifacts-read"
  role = aws_iam_role.ec2.id

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

resource "aws_iam_instance_profile" "ec2" {
  name = "brokerone-dev-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_iam_role_policy" "filestorage_rw" {
  name = "brokerone-dev-filestorage"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FileStorageObjects"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::brokerone-dev-filestorage/*"
      },
      {
        Sid      = "FileStorageList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::brokerone-dev-filestorage"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ses_send" {
  name = "brokerone-dev-ses-send"
  role = aws_iam_role.ec2.id

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
