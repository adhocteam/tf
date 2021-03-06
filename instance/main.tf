terraform {
  required_version = ">= 0.12"
}

resource "aws_instance" "box" {
  count         = var.instance_count
  ami           = var.base.ami.id
  instance_type = var.instance_size

  iam_instance_profile = aws_iam_instance_profile.iam.name
  user_data            = var.user_data != "" ? var.user_data : null
  key_name             = var.base.ssh_key

  associate_public_ip_address = false

  #distribute instances across AZs, use element for wrap around support
  subnet_id = element(var.base.vpc.application[*].id, count.index)
  vpc_security_group_ids = [
    var.base.security_groups["teleport_nodes"].id,
    var.base.security_groups["jumpbox_nodes"].id,
    aws_security_group.app.id
  ]

  lifecycle {
    ignore_changes        = [ami]
    create_before_destroy = true
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

# Convenient internal DNS name for other items in VPC to use if needed
resource "aws_route53_record" "box" {
  zone_id = var.base.vpc.internal_dns.zone_id
  name    = var.application_name
  type    = "CNAME"
  ttl     = 30

  records = aws_instance.box[*].private_dns
}

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
  role       = aws_iam_role.iam.name
  policy_arn = "arn:aws:iam::${var.base.account.account_id}:policy/${var.base.env}/teleport/${var.base.env}-instance-teleport-secrets"
}

