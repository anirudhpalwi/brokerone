resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*+-_=."
}

resource "aws_db_subnet_group" "brokerone" {
  name = "brokerone-dev-db-subnet-group"

  subnet_ids = [
    aws_subnet.db_a.id,
    aws_subnet.db_b.id
  ]

  tags = {
    Name = "brokerone-dev-db-subnet-group"
  }
}

resource "aws_db_instance" "brokerone" {
  identifier = "brokerone-dev"

  engine                      = "postgres"
  engine_version              = var.postgres_engine_version
  allow_major_version_upgrade = true
  instance_class              = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.brokerone.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  # Single-AZ is an accepted risk for DEV (Multi-AZ doubles cost).
  multi_az                = false
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name = "brokerone-dev-rds"
  }
}

resource "aws_secretsmanager_secret" "db" {
  name = "brokerone-dev-postgres-secret-v2"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    host     = aws_db_instance.brokerone.address
    port     = aws_db_instance.brokerone.port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.db.result
  })
}

resource "aws_iam_policy" "secret_read" {
  name = "brokerone-dev-secret-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.db.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secret_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.secret_read.arn
}
