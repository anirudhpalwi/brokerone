resource "aws_security_group" "alb" {
  name        = "brokerone-dev-alb-sg"
  description = "Public HTTP and HTTPS access to BrokerOne ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "brokerone-dev-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from internet"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ec2" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to BrokerOne Node.js"
  from_port                    = 5192
  to_port                      = 5192
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2.id
}

resource "aws_security_group" "ec2" {
  name        = "brokerone-dev-ec2-sg"
  description = "BrokerOne EC2 security group"
  vpc_id      = var.vpc_id

  tags = {
    Name = "brokerone-dev-ec2-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "ec2_https_outbound" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTPS to AWS APIs and package repos via NAT"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_rds" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "PostgreSQL to BrokerOne RDS"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds.id
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 5192
  to_port                      = 5192
  ip_protocol                  = "tcp"
  description                  = "ALB to BrokerOne Node.js"
}

resource "aws_security_group" "rds" {
  name        = "brokerone-dev-rds-sg"
  description = "BrokerOne RDS PostgreSQL access only from EC2"
  vpc_id      = var.vpc_id

  tags = {
    Name = "brokerone-dev-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ec2" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from BrokerOne EC2"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2.id
}

# No RDS egress rule: RDS only answers connections, and security groups are
# stateful, so replies to the EC2 are allowed without one.
