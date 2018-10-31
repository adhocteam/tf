module "base" {
  source = "../app_base"

  env               = "${var.env}"
  domain_name       = "${var.domain_name}"
  application_name  = "${var.application_name}"
  application_port  = "${var.application_port}"
  loadbalancer_port = "${var.loadbalancer_port}"
}

resource "aws_instance" "application" {
  count         = "${var.instance_count}"
  ami           = "${data.aws_ami.base.id}"
  instance_type = "${var.instance_size}"

  iam_instance_profile = "${aws_iam_instance_profile.iam}"
  user_data            = "${var.user_data}"
  key_name             = "${var.key_pair}"

  associate_public_ip_address = false

  #distribute instances across AZs
  subnet_id              = "${element(data.aws_subnet.application_subnet.*.id,count.index)}"
  vpc_security_group_ids = ["${module.base.app_sg_id}"]

  lifecycle {
    ignore_changes = ["ami"]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags {
    Name = "${var.application_name}-${count.index}"
    app  = "${var.application_name}"
    env  = "${var.env}"
  }
}

resource "aws_alb_target_group_attachment" "application_targets" {
  count            = "${var.instance_count}"
  target_group_arn = "${module.base.lb_tg_arn}"
  target_id        = "${element(aws_instance.application.*.private_ip, count.index)}"
}

# Add rule to allow SSH proxies to connect
resource "aws_security_group_rule" "proxy_ssh" {
  type                     = "ingress"
  from_port                = 3022
  to_port                  = 3022
  protocol                 = "tcp"
  source_security_group_id = "${data.aws_security_group.ssh_proxies.id}"

  security_group_id = "${module.base.app_sg_id}"
}

resource "aws_security_group_rule" "jumpbox" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${data.aws_security_group.jumpbox.id}"

  security_group_id = "${module.base.app_sg_id}"
}

#####
# Base IAM instance profile
#####
resource "aws_iam_instance_profile" "iam" {
  name = "${var.env}-plain-instance"
  role = "${aws_iam_role.iam.name}"
}

# Auth instance profile and roles
resource "aws_iam_role" "iam" {
  name = "${var.env}-plain-instance"

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
  path        = "/${var.env}/plain-instance/"
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
  name              = "${env}-${application_name}-main"
  key_id            = "${data.aws_kms_alias.main.target_key_arn}"
  grantee_principal = "${aws_iam_role.iam.arn}"
  operations        = ["Decrypt"]
}
