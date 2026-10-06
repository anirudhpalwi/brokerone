resource "aws_cloudwatch_log_group" "brokerone_app" {
  name              = "/brokerone-dev/app"
  retention_in_days = 30

  tags = {
    Name = "brokerone-dev-app-logs"
  }
}
