locals {
  db_port = var.db_engine == "postgres" ? 5432 : 3306
}

resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.data[*].id

  tags = { Name = "${local.name}-db-subnets" }
}

# Password is generated here and never written to a variable file.
resource "random_password" "db" {
  length  = 24
  special = true
  # RDS rejects these characters in master passwords.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name}/db/master"
  recovery_window_in_days = 0 # set to 7-30 in prod
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    host     = aws_db_instance.this.address
    port     = local.db_port
    dbname   = var.db_name
    engine   = var.db_engine
  })
}

resource "aws_db_instance" "this" {
  identifier     = "${local.name}-db"
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 5
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = local.db_port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period = var.db_backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:30-Mon:05:30"

  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = !var.deletion_protection
  final_snapshot_identifier  = var.deletion_protection ? "${local.name}-db-final" : null

  performance_insights_enabled = false
  monitoring_interval          = 0

  tags = { Name = "${local.name}-db" }
}
