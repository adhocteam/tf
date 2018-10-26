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

  iam_instance_profile = "${var.instance_role}"
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
