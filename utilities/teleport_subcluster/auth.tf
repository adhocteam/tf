#######
# The authenticators handle queries for identification and authorization
# from the proxies and hand-out ssh certificates
#######

#######
# Load balancer for internal instances
#######

resource "aws_lb" "auth" {
  name_prefix                      = "telep-"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = var.base.vpc.application[*].id
  enable_cross_zone_load_balancing = true

  ip_address_type = "ipv4"

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    name      = "lb-teleport-auth-internal"
  }
}

# Must use target type IP to allow auth instances to call back through the LB
# https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-troubleshooting.html
resource "aws_lb_target_group" "auth" {
  name_prefix = "telep-"
  port        = 3025
  protocol    = "TCP"
  vpc_id      = var.base.vpc.id
  target_type = "ip"

  depends_on = [aws_lb.auth]

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    Name      = "lb-tg-telport-auth"
  }
}

resource "aws_lb_listener" "auth" {
  load_balancer_arn = aws_lb.auth.arn
  port              = 3025
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.auth.arn
    type             = "forward"
  }
}

#######
# Auth instances
#######

resource "aws_instance" "auths" {
  count         = var.auth_count
  ami           = var.base.ami.id
  instance_type = "t3.nano"
  key_name      = var.base.ssh_key

  iam_instance_profile = aws_iam_instance_profile.auth.name
  user_data = templatefile("${path.module}/auth-user-data.tmpl", {
    nodename                 = "teleport-auth-${count.index}"
    cluster_token            = data.aws_secretsmanager_secret_version.cluster_token.secret_string
    region                   = var.base.region.name
    dynamo_table_name        = aws_dynamodb_table.teleport_state.name
    dynamo_events_table_name = aws_dynamodb_table.teleport_events.name
    s3_bucket                = aws_s3_bucket.recordings.id
    cluster_name             = var.base.env
    main_cluster             = var.main_cluster
    main_cluster_token       = data.aws_secretsmanager_secret_version.main_cluster_token.secret_string
    main_cluster_url         = "teleport.${var.base.domain_name}"
  })

  associate_public_ip_address = false
  subnet_id                   = element(var.base.vpc.application[*].id, count.index)
  vpc_security_group_ids = [
    var.base.security_groups["jumpbox_nodes"].id,
    aws_security_group.auths.id
  ]

  lifecycle {
    ignore_changes = [ami]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true
  }

  tags = {
    Name      = "teleport-auth-${count.index}"
    app       = "teleport"
    env       = var.base.env
    terraform = "true"
  }
}

# Add to target group to attach to LB

resource "aws_lb_target_group_attachment" "auth" {
  count            = var.auth_count
  target_group_arn = aws_lb_target_group.auth.arn
  target_id        = aws_instance.auths[count.index].private_ip
}

#######
### Security group for proxy instances
#######

resource "aws_security_group" "auths" {
  name_prefix = "teleport-auth-"
  vpc_id      = var.base.vpc.id

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-auth"
  }
}

resource "aws_security_group_rule" "auth_webui" {
  type        = "ingress"
  from_port   = 3025
  to_port     = 3025
  protocol    = "tcp"
  cidr_blocks = [var.base.vpc.cidr_block]

  security_group_id = aws_security_group.auths.id
}

# Allow it to talk to any address to be able to hit AWS APIs for Dynamo, S3
resource "aws_security_group_rule" "auth_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.auths.id
}

#######
# DynamoDB table to store cluster state and audit events
# TODO(bob) enable autoscaling of dynamodb capacity
# cf. https://github.com/gravitational/teleport/blob/master/examples/aws/terraform/dynamo.tf
#######

// Dynamodb is used as a backend for auth servers,
// and only auth servers need access to the tables
// all other components are stateless.
resource "aws_dynamodb_table" "teleport_state" {
  name           = "${var.base.env}-teleport-state"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "HashKey"
  range_key      = "FullPath"

  server_side_encryption {
    enabled = true
  }

  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity,
    ]
  }

  attribute {
    name = "HashKey"
    type = "S"
  }

  attribute {
    name = "FullPath"
    type = "S"
  }

  ttl {
    attribute_name = "Expires"
    enabled        = true
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-auth-state"
  }
}

// Dynamodb events table stores events
resource "aws_dynamodb_table" "teleport_events" {
  name           = "${var.base.env}-teleport-events"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "SessionID"
  range_key      = "EventIndex"

  server_side_encryption {
    enabled = true
  }

  global_secondary_index {
    name            = "timesearch"
    hash_key        = "EventNamespace"
    range_key       = "CreatedAt"
    write_capacity  = 20
    read_capacity   = 20
    projection_type = "ALL"
  }

  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity,
    ]
  }

  attribute {
    name = "SessionID"
    type = "S"
  }

  attribute {
    name = "EventIndex"
    type = "N"
  }

  attribute {
    name = "EventNamespace"
    type = "S"
  }

  attribute {
    name = "CreatedAt"
    type = "N"
  }

  ttl {
    attribute_name = "Expires"
    enabled        = true
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-auth-audit"
  }
}

#######
# S3 Bucket to store session recordings
#######

resource "random_id" "unique_bucket" {
  byte_length = 8
}

resource "aws_s3_bucket" "recordings" {
  bucket        = "${var.base.env}-teleport-${lower(random_id.unique_bucket.hex)}"
  acl           = "private"
  force_destroy = true

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = var.base.key.arn #TODO(bob) switch to unique, restricted key here?
        sse_algorithm     = "aws:kms"
      }
    }
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
  }
}

#######
# IAM to allow access to Dynamo and S3 resources
#######

resource "aws_iam_instance_profile" "auth" {
  name = "${var.base.env}-teleport-auth"
  role = aws_iam_role.auth.name
}

// Auth instance profile and roles
resource "aws_iam_role" "auth" {
  name = "${var.base.env}-teleport-auth"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

}

// Auth server uses DynamoDB as a backend, and this is to allow read/write from the dynamo tables
resource "aws_iam_role_policy" "auth_dynamo" {
  name = "${var.base.env}-teleport-auth-dynamo"
  role = aws_iam_role.auth.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllActionsOnTeleportDB",
            "Effect": "Allow",
            "Action": "dynamodb:*",
            "Resource": "${aws_dynamodb_table.teleport_state.arn}"
        },
        {
            "Sid": "AllActionsOnTeleportEventsDB",
            "Effect": "Allow",
            "Action": "dynamodb:*",
            "Resource": "${aws_dynamodb_table.teleport_events.arn}"
        },
        {
            "Sid": "AllActionsOnTeleportEventsIndexDB",
            "Effect": "Allow",
            "Action": "dynamodb:*",
            "Resource": "${aws_dynamodb_table.teleport_events.arn}/index/*"
        }
    ]
}
EOF

}

// S3 for publishing session recordings to S3 encrypted bucket
resource "aws_iam_role_policy" "auth_s3" {
name = "${var.base.env}-teleport-auth-s3"
role = aws_iam_role.auth.id

policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
     {
       "Effect": "Allow",
       "Action": ["s3:ListBucket"],
       "Resource": ["${aws_s3_bucket.recordings.arn}"]
     },
     {
       "Effect": "Allow",
       "Action": [
         "s3:PutObject",
         "s3:GetObject"
       ],
       "Resource": ["${aws_s3_bucket.recordings.arn}/*"]
     },
     {
        "Effect": "Allow",
        "Action": [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:GenerateDataKey"
        ],
        "Resource": ["${var.base.key.arn}"]
     }
   ]
 }
 
EOF

}

