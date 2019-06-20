terraform {
  required_version = ">= 0.12"
}

resource "aws_instance" "box" {
  count         = var.instance_count
  ami           = var.base.ami.id
  instance_type = var.instance_size

  iam_instance_profile = aws_iam_instance_profile.iam.name
  user_data            = var.user_data != "" ? var.user_data : null
  key_name             = var.key_pair

  associate_public_ip_address = false

  #distribute instances across AZs
  subnet_id = var.base.vpc.application[count.index].id
  vpc_security_group_ids = [
    var.base.security_groups["teleport_nodes"].id,
    var.base.security_groups["jumpbox_nodes"].id,
    aws_security_group.app.id
  ]

  lifecycle {
    ignore_changes = [ami]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.volume_size
    delete_on_termination = true
  }

  tags = {
    Name      = "${var.application_name}-${count.index}"
    app       = var.application_name
    terraform = "true"
    env       = var.base.env
  }
}

# resource "aws_alb_target_group_attachment" "application_targets" {
#   count            = var.instance_count
#   target_group_arn = var.base.lb_tg_arn
#   target_id        = element(aws_instance.application.*.private_ip, count.index)
# }

#######
# Security group for application
#######

resource "aws_security_group" "app" {
  name_prefix = "${var.application_name}-app-"
  vpc_id      = var.base.vpc.id

  tags = {
    app       = var.application_name
    terraform = "true"
    env       = var.base.env
  }
}

# Allow all outbound, e.g. third-pary API endpoints, by default
resource "aws_security_group_rule" "egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.app.id
}


#####
# Base IAM instance profile
#####
resource "aws_iam_instance_profile" "iam" {
  name = "${var.base.env}-plain-instance-${var.application_name}"
  role = aws_iam_role.iam.name
}

# Auth instance profile and roles
resource "aws_iam_role" "iam" {
  name = "${var.base.env}-plain-instance-${var.application_name}"

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

# Give it base teleport permissions
resource "aws_iam_role_policy_attachment" "iam_teleport" {
  role = aws_iam_role.iam.name
  policy_arn = "arn:aws:iam::${var.base.account.account_id}:policy/${var.base.env}/teleport/${var.base.env}-instance-teleport-secrets"
}

resource "aws_kms_grant" "main" {
  name = "${var.base.env}-${var.application_name}-main"
  key_id = var.base.key.arn
  grantee_principal = aws_iam_role.iam.arn
  operations = ["Decrypt"]
}


#####
# Target group in case it needs to be attached to an LB
#####

resource "aws_alb_target_group" "application" {
  # max 6 characters for name prefix
  name_prefix = "app-lb"
  port = var.application_port
  protocol = "HTTP"
  vpc_id = var.base.vpc.id
  target_type = "ip" # Must use IP to support fargate

  health_check {
    interval = 60
    path = var.health_check_path
    port = var.application_port
    healthy_threshold = 2
    unhealthy_threshold = 2
  }

  tags = {
    env = var.base.env
    terraform = "true"
    app = var.application_name
    name = "app-lb-${var.application_name}"
  }
}

resource "aws_alb_target_group_attachment" "application" {
  count = length(aws_instance.box)
  target_group_arn = aws_alb_target_group.application.arn
  target_id = aws_instance.box[count.index].private_ip
}
