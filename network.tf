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
