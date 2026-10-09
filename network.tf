data "aws_vpc" "brokerone" {
  id = var.vpc_id
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]
}

resource "aws_subnet" "public_a" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_a_cidr
  availability_zone       = local.az_a
  map_public_ip_on_launch = true

  tags = {
    Name = "brokerone-dev-public-a"
    Tier = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.public_subnet_b_cidr
  availability_zone       = local.az_b
  map_public_ip_on_launch = true

  tags = {
    Name = "brokerone-dev-public-b"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_id
  }

  tags = {
    Name = "brokerone-dev-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "db_a" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.db_subnet_a_cidr
  availability_zone       = local.az_a
  map_public_ip_on_launch = false

  tags = {
    Name = "brokerone-dev-db-a"
    Tier = "database"
  }
}

resource "aws_subnet" "db_b" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.db_subnet_b_cidr
  availability_zone       = local.az_b
  map_public_ip_on_launch = false

  tags = {
    Name = "brokerone-dev-db-b"
    Tier = "database"
  }
}

resource "aws_route_table" "db" {
  vpc_id = var.vpc_id

  tags = {
    Name = "brokerone-dev-db-rt"
  }
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.db.id
}

resource "aws_route_table_association" "db_b" {
  subnet_id      = aws_subnet.db_b.id
  route_table_id = aws_route_table.db.id
}

# Private app subnets: the EC2 has no public IP and reaches the internet
# (dnf/npm, SSM, CodeCommit, SES) through the NAT gateway
# (Scrut: "Instance with a Public IP Address").
resource "aws_subnet" "private_a" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.private_subnet_a_cidr
  availability_zone       = local.az_a
  map_public_ip_on_launch = false

  tags = {
    Name = "brokerone-dev-private-a"
    Tier = "private"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id                  = var.vpc_id
  cidr_block              = var.private_subnet_b_cidr
  availability_zone       = local.az_b
  map_public_ip_on_launch = false

  tags = {
    Name = "brokerone-dev-private-b"
    Tier = "private"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "brokerone-dev-nat-eip"
  }
}

resource "aws_nat_gateway" "brokerone" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "brokerone-dev-nat"
  }
}

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.brokerone.id
  }

  tags = {
    Name = "brokerone-dev-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Custom NACLs replace the default allow-all NACL (Scrut: "Network ACLs ...
# should not allow all ingress/egress traffic"). NACLs are stateless, so every
# allowed connection also needs a rule for its reply traffic (ports 1024-65535).

# Public subnets: ALB + app EC2.
resource "aws_network_acl" "public" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  # HTTPS and HTTP from users to the ALB
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  # ALB to the app
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_a_cidr
    from_port  = 5192
    to_port    = 5192
  }
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_b_cidr
    from_port  = 5192
    to_port    = 5192
  }
  # Replies to the EC2's outbound calls (npm, dnf, SSM, S3, SES, CodeCommit) and from RDS
  ingress {
    rule_no    = 140
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # HTTPS and HTTP to AWS services and package sites
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  # ALB to the app
  egress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_a_cidr
    from_port  = 5192
    to_port    = 5192
  }
  egress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_b_cidr
    from_port  = 5192
    to_port    = 5192
  }
  # App to RDS
  egress {
    rule_no    = 140
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.db_subnet_a_cidr
    from_port  = 5432
    to_port    = 5432
  }
  egress {
    rule_no    = 150
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.db_subnet_b_cidr
    from_port  = 5432
    to_port    = 5432
  }
  # Replies from the ALB to users and from the app to the ALB
  egress {
    rule_no    = 160
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  # ALB to the app in the private subnets
  egress {
    rule_no    = 170
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.private_subnet_a_cidr
    from_port  = 5192
    to_port    = 5192
  }
  egress {
    rule_no    = 180
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.private_subnet_b_cidr
    from_port  = 5192
    to_port    = 5192
  }
  # NAT gateway traffic needs no extra rules: it arrives on 80/443 (ingress 100/110),
  # leaves on 80/443 (egress 100/110), and replies use 1024-65535 (ingress 140, egress 160).

  tags = {
    Name = "brokerone-dev-public-nacl"
  }
}

# Private app subnets: ALB in on 5192, app out to the internet (via NAT) and to RDS.
resource "aws_network_acl" "private" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  # ALB to the app
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_a_cidr
    from_port  = 5192
    to_port    = 5192
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_b_cidr
    from_port  = 5192
    to_port    = 5192
  }
  # Replies from the internet (via NAT) and from RDS
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # HTTPS and HTTP out through the NAT gateway
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  # App to RDS
  egress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.db_subnet_a_cidr
    from_port  = 5432
    to_port    = 5432
  }
  egress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.db_subnet_b_cidr
    from_port  = 5432
    to_port    = 5432
  }
  # Replies to the ALB
  egress {
    rule_no    = 140
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "brokerone-dev-private-nacl"
  }
}

# Database subnets: PostgreSQL in from the app subnets only, replies back to them.
resource "aws_network_acl" "db" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_b.id]

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_a_cidr
    from_port  = 5432
    to_port    = 5432
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_b_cidr
    from_port  = 5432
    to_port    = 5432
  }

  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_a_cidr
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.public_subnet_b_cidr
    from_port  = 1024
    to_port    = 65535
  }

  # App in the private subnets
  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.private_subnet_a_cidr
    from_port  = 5432
    to_port    = 5432
  }
  ingress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.private_subnet_b_cidr
    from_port  = 5432
    to_port    = 5432
  }
  egress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.private_subnet_a_cidr
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 130
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.private_subnet_b_cidr
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "brokerone-dev-db-nacl"
  }
}
