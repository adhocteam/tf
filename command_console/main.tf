resource "aws_instance" "console" {
  ami           = "${data.aws_ami.base.id}"
  instance_type = "${var.instance_size}"

  iam_instance_profile = "${aws_iam_instance_profile.iam.name}"
  user_data            = "${var.user_data}"
  key_name             = "${var.key_pair}"

  associate_public_ip_address = false

  #distribute instances across AZs
  subnet_id              = "${element(data.aws_subnet.application_subnet.*.id,0)}"
  vpc_security_group_ids = ["${aws_security_group.sg.id}"]

  lifecycle {
    ignore_changes = ["ami"]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags {
    Name = "command-console-${var.env}"
    app  = "command-console"
    env  = "${var.env}"
  }
}

#####
# Security group
#####
resource "aws_security_group" "sg" {
  name_prefix = "console-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    app = "command-console"
    env = "${var.env}"
  }
}

# Allow all outbound, e.g. third-pary API endpoints, by default
resource "aws_security_group_rule" "egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.sg.id}"
}

# Add rule to allow SSH proxies to connect
resource "aws_security_group_rule" "proxy_ssh" {
  type                     = "ingress"
  from_port                = 3022
  to_port                  = 3022
  protocol                 = "tcp"
  source_security_group_id = "${data.aws_security_group.ssh_proxies.id}"

  security_group_id = "${aws_security_group.sg.id}"
}

resource "aws_security_group_rule" "jumpbox" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${data.aws_security_group.jumpbox.id}"

  security_group_id = "${aws_security_group.sg.id}"
}

#####
# Base IAM instance profile
#####
resource "aws_iam_instance_profile" "iam" {
  name = "${var.env}-command-console"
  role = "${aws_iam_role.iam.name}"
}

# Auth instance profile and roles
resource "aws_iam_role" "iam" {
  name = "${var.env}-command-console"

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
  role       = "${aws_iam_role.iam.name}"
  policy_arn = "${aws_iam_policy.teleport_secrets.arn}"
}

### Shared IAM role for teleport
resource "aws_iam_policy" "teleport_secrets" {
  name        = "instance-teleport-secrets"
  path        = "/${var.env}/command-console/"
  description = "Allows nodes to run local teleport daemon"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect" : "Allow",
            "Action" : "ec2:DescribeTags",
            "Resource" : "*"
        },
        {
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "${data.aws_secretsmanager_secret.cluster_token.arn}"
        },
        {
            "Effect": "Allow",
            "Action": "kms:Decrypt",
            "Resource": "${data.aws_kms_alias.main.target_key_arn}"
        }
    ]
}
EOF
}

resource "aws_kms_grant" "main" {
  name              = "${var.env}-command-console-main"
  key_id            = "${data.aws_kms_alias.main.target_key_arn}"
  grantee_principal = "${aws_iam_role.iam.arn}"
  operations        = ["Decrypt"]
}
