#######
# If var.emergency_bastion is set to 1 this provisions a
# jumpbox allowing SSH access to the Teleport hosts. Useful for initial
# Ansible setup or debugging.
#
# Once complete, this should be set back to 0 to remove the jumpbox
#######

terraform {
  required_version = ">= 0.12"
}

#######
# Jumpbox instances
#######

# Ensure at most 1 jumpbox created
locals {
  enabled = var.enabled ? 1 : 0
}

resource "aws_instance" "jumpbox" {
  count         = local.enabled
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.nano"

  # TODO(bob) use https://github.com/widdix/aws-ec2-ssh to control access here?
  key_name = var.key_pair

  associate_public_ip_address = true
  subnet_id                   = var.base.public[count.index].id
  vpc_security_group_ids      = [var.base.security_groups["jumpbox"].id]

  lifecycle {
    ignore_changes = [ami]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name      = "jumpbox"
    app       = "utilities"
    env       = var.base.env
    terraform = "true"
  }
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
  count   = local.enabled
  zone_id = var.base.external.id
  name    = "jumpbox.${var.base.env}"
  type    = "CNAME"
  ttl     = 30

  records = [aws_instance.jumpbox[0].public_dns]
}

