resource "aws_lb" "brokerone" {
  name               = "brokerone-dev-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  drop_invalid_header_fields = true
  enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = "alb"
    enabled = true
  }

  tags = {
    Name = "brokerone-dev-alb"
  }

  # ALB validates write access to the log bucket when logging is enabled.
  depends_on = [aws_s3_bucket_policy.logs]
}

resource "aws_lb_target_group" "brokerone" {
  name        = "brokerone-dev-tg"
  port        = 5192
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/api/health"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "brokerone-dev-tg"
  }
}

resource "aws_lb_target_group_attachment" "brokerone" {
  target_group_arn = aws_lb_target_group.brokerone.arn
  target_id        = aws_instance.brokerone.id
  port             = 5192
}

resource "aws_acm_certificate" "brokerone" {
  domain_name       = var.brokerone_fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "brokerone-dev-cert"
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.brokerone.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "brokerone" {
  certificate_arn = aws_acm_certificate.brokerone.arn

  validation_record_fqdns = [
    for record in aws_route53_record.validation :
    record.fqdn
  ]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.brokerone.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.brokerone.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.brokerone.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.brokerone.arn
  }
}

resource "aws_route53_record" "brokerone" {
  zone_id = var.hosted_zone_id
  name    = var.brokerone_fqdn
  type    = "A"

  alias {
    name                   = aws_lb.brokerone.dns_name
    zone_id                = aws_lb.brokerone.zone_id
    evaluate_target_health = true
  }
}
