#######
# If var.emergency_bastion is set to 1 this provisions a
# jumpbox allowing SSH access to the Teleport hosts. Useful for initial
# Ansible setup or debugging.
#
# Once complete, this should be set back to 0 to remove the jumpbox
#######

#######
# Jumpbox instances
#######

# Ensure at most 1 jumpbox created
locals {
  enabled = "${var.enabled ? 1 : 0}"
}

resource "aws_instance" "jumpbox" {
  count         = "${local.enabled}"
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "t3.nano"

  # TODO(bob) use https://github.com/widdix/aws-ec2-ssh to control access here?
  key_name = "${var.key_pair}"

  associate_public_ip_address = true
  subnet_id                   = "${element(data.aws_subnet.public_subnet.*.id,count.index)}"
  vpc_security_group_ids      = ["${aws_security_group.jumpbox.id}"]

  lifecycle {
    ignore_changes = ["ami"]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags {
    Name      = "jumpbox"
    app       = "utilities"
    env       = "${var.env}"
    terraform = "true"
  }
}

#######
# Security group for jumpbox
#######

resource "aws_security_group" "jumpbox" {
  name_prefix = "jumpbox-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "utilities"
    Name      = "jumpbox"
  }
}

resource "aws_security_group_rule" "jumpbox_ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.jumpbox.id}"
}

resource "aws_security_group_rule" "jump_into_vpc" {
  type        = "egress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["${data.aws_vpc.vpc.cidr_block}"]

  security_group_id = "${aws_security_group.jumpbox.id}"
}

# TODO(bob) If using https://github.com/widdix/aws-ec2-ssh
# then will need to open this up

# resource "aws_security_group_rule" "jump_into_vpc" {
#   type              = "egress"
#   from_port         = 0
#   to_port           = 0
#   protocol          = "-1"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = "${aws_security_group.jumpbox.id}"
# }

#######
# Domain name for the instance
#######

resource "aws_route53_record" "jumpbox" {
  count   = "${local.enabled}"
  zone_id = "${data.aws_route53_zone.external.id}"
  name    = "jumpbox.${var.env}"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_instance.jumpbox.public_dns}"]
}
