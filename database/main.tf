terraform {
  required_version = ">= 0.12"
}

####
# Setup database specific networking
####

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.base.env}-${var.application.name}-rds-subnet-group"
  subnet_ids = var.base.vpc.data[*].id
}

resource "aws_security_group" "db_sg" {
  name        = "${var.base.env}-${var.application.name}-db-sg"
  description = "SG for database servers"
  vpc_id      = var.base.vpc.id
}

resource "aws_security_group_rule" "ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.application.security_group.id

  security_group_id = aws_security_group.db_sg.id
}

resource "aws_security_group_rule" "egress" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.application.security_group.id

  security_group_id = aws_security_group.db_sg.id
}

####
# Create RDS resources
####

resource "aws_db_instance" "primary" {
  identifier_prefix = "${var.base.env}-${var.application.name}-"

  username = var.user
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  multi_az               = true

  instance_class = var.instance_class
  engine         = "postgres"
  engine_version = "10.5"
  port           = 5432

  storage_type        = "gp2"
  skip_final_snapshot = true
  allocated_storage   = 120
  storage_encrypted   = true
  kms_key_id          = var.base.key.arn

  parameter_group_name            = aws_db_parameter_group.postgres.id
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  monitoring_interval = 30
  monitoring_role_arn = aws_iam_role.monitoring.arn

  backup_retention_period = 7

  lifecycle {
    ignore_changes = [
      snapshot_identifier,
      engine_version,
    ]
  }

  tags = {
    env       = var.base.env
    app       = var.application.name
    terraform = "true"
    name      = "${var.base.env}-db"
  }
}

# Enable query logging
resource "aws_db_parameter_group" "postgres" {
  name_prefix = "${var.base.env}-${var.application.name}-"
  family      = "postgres10"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  # Log only IP address to prevent potential performance penalty
  # https://www.postgresql.org/docs/9.5/runtime-config-logging.html#what-to-log
  parameter {
    name  = "log_hostname"
    value = "0"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  # Enable pg_stat_statements for extra analytics
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "pg_stat_statements.track"
    value = "ALL"
  }

  parameter {
    name         = "track_activity_query_size"
    value        = "2048"
    apply_method = "pending-reboot"
  }
}

####
# Create internal DNS entry for easy reference by the application
####

resource "aws_route53_record" "rds_cname" {
  zone_id = var.base.internal_dns.id
  name    = "${var.application.name}-db-primary"
  type    = "CNAME"
  ttl     = 30

  records = [aws_db_instance.primary.address]
}

##################################################
# Create an IAM role to allow enhanced monitoring
##################################################
resource "aws_iam_role" "monitoring" {
  name = "${var.base.env}-${var.application.name}-rds-monitoring-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"Service": "monitoring.rds.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

## TODO(bob) Add read replicas?
## TODO(bob) Store username/password in secrets manager with rotation
