resource "random_id" "backup_bucket_suffix" {
  byte_length = 3
}

resource "aws_db_subnet_group" "postgres" {
  name       = "${local.name_prefix}-db-subnets"
  subnet_ids = [for subnet in values(aws_subnet.private) : subnet.id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnets"
  })
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Allow PostgreSQL traffic from ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-sg"
  })
}

resource "aws_db_instance" "postgres" {
  identifier                      = "${local.name_prefix}-postgres"
  allocated_storage               = var.db_allocated_storage
  max_allocated_storage           = var.db_allocated_storage * 2
  engine                          = "postgres"
  engine_version                  = "16.4"
  instance_class                  = var.db_instance_class
  db_subnet_group_name            = aws_db_subnet_group.postgres.name
  vpc_security_group_ids          = [aws_security_group.rds.id]
  publicly_accessible             = false
  multi_az                        = false
  storage_encrypted               = true
  deletion_protection             = false
  backup_retention_period         = var.db_backup_retention_days
  backup_window                   = "16:00-17:00" # UTC
  maintenance_window              = "sun:17:00-sun:18:00"
  enabled_cloudwatch_logs_exports = ["postgresql"]

  username = var.db_username
  password = var.db_password
  db_name  = var.db_name

  apply_immediately = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-postgres"
  })
}

resource "aws_s3_bucket" "rds_backups" {
  bucket        = "${local.name_prefix}-rds-backups-${random_id.backup_bucket_suffix.hex}"
  force_destroy = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-rds-backups"
  })
}

resource "aws_s3_bucket_versioning" "rds_backups" {
  bucket = aws_s3_bucket.rds_backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "rds_backups" {
  bucket = aws_s3_bucket.rds_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "rds_backups" {
  bucket = aws_s3_bucket.rds_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "rds_backups" {
  bucket = aws_s3_bucket.rds_backups.id

  rule {
    id     = "expire-old-dumps"
    status = "Enabled"
    filter {
      prefix = ""
    }
    expiration {
      days = 30
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
