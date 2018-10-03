####
# Pull in external data for use here
####

data "aws_route53_zone" "internal" {
  name         = "${var.name}.local"
  private_zone = true
}

data "aws_vpc" "vpc" {
  tags {
    env = "${var.name}"
  }
}

data "aws_subnet" "data_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "data-sub-${count.index}"
    env  = "${var.name}"
  }
}

data "aws_subnet" "application_subnet" {
  count  = 3
  vpc_id = "${data.aws_vpc.vpc.id}"

  tags {
    name = "app-sub-${count.index}"
    env  = "${var.name}"
  }
}

data "aws_kms_key" "main" {
  key_id = "alias/${var.name}-main"
}

####
# Setup database specific networking
####

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "rds_subnet_group"
  subnet_ids = ["${data.aws_subnet.data_subnet.*.id}"]
}

resource "aws_security_group" "db-sg" {
  name        = "db-sg"
  description = "SG for database servers"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["${var.app-sg}"]
  }

  # TODO(bob) Can probably lock this down to just 5432 to apps
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

####
# Create RDS resources
####

resource "aws_db_instance" "primary" {
  identifier_prefix = "${var.name}-"

  username = "${var.user}"
  password = "${var.password}"

  db_subnet_group_name   = "${aws_db_subnet_group.db_subnet_group.id}"
  vpc_security_group_ids = ["${aws_security_group.db-sg.id}"]
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
    env       = "${var.name}"
    app       = "${var.app-name}"
    terraform = "true"
    name      = "${var.name}-db"
  }
}

####
# Create internal DNS entry for easy reference by the application
####

resource "aws_route53_record" "rds-cname" {
  zone_id = "${data.aws_route53_zone.internal.id}"
  name    = "${var.app-name}-db-primary.${var.name}.local"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_db_instance.primary.address}"]
}

## TODO(bob) Add read replicas?
## TODO(bob) Store username/password in secrets manager with rotation

