####
# Setup database specific networking
####

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.env}-${var.application_name}-rds-subnet-group"
  subnet_ids = ["${data.aws_subnet.data_subnet.*.id}"]
}

resource "aws_security_group" "db_sg" {
  name        = "${var.env}-${var.application_name}-db-sg"
  description = "SG for database servers"
  vpc_id      = "${data.aws_vpc.vpc.id}"
}

resource "aws_security_group_rule" "app_gress" {
  type            = "ingress"
  from_port       = 5432
  to_port         = 5432
  protocol        = "tcp"
  security_groups = ["${var.app_sg}"]

  security_group_id = "${aws_security_group.db_sg}"
}

# TODO(bob) confirm this can be locked to egress 5432 only
resource "aws_security_group_rule" "egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.db_sg}"
}

####
# Create RDS resources
####

resource "aws_db_instance" "primary" {
  identifier_prefix = "${var.env}-"

  username = "${var.user}"
  password = "${var.password}"

  db_subnet_group_name   = "${aws_db_subnet_group.db_subnet_group.id}"
  vpc_security_group_ids = ["${aws_security_group.db_sg.id}"]
  publicly_accessible    = false
  multi_az               = true

  instance_class = "db.t2.small"
  engine         = "postgres"
  engine_version = "9.6.9"
  port           = 5432

  storage_type        = "gp2"
  skip_final_snapshot = true
  allocated_storage   = 10
  storage_encrypted   = true
  kms_key_id          = "${data.aws_kms_key.main.arn}"

  backup_retention_period = 7

  lifecycle {
    ignore_changes = ["snapshot_identifier",
      "engine_version",
    ]
  }

  tags {
    env       = "${var.env}"
    app       = "${var.application_name}"
    terraform = "true"
    name      = "${var.env}-db"
  }
}

####
# Create internal DNS entry for easy reference by the application
####

resource "aws_route53_record" "rds_cname" {
  zone_id = "${data.aws_route53_zone.internal.id}"
  name    = "${var.application_name}-db-primary"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_db_instance.primary.address}"]
}

## TODO(bob) Add read replicas?
## TODO(bob) Store username/password in secrets manager with rotation

