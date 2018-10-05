module "base" {
  source = "../app-base"

  name              = "${var.name}"
  domain_name       = "${var.domain_name}"
  application_name  = "${var.application_name}"
  application_port  = "${var.application_port}"
  loadbalancer_port = "${var.loadbalancer_port}"
}

data "template_file" "user_data" {
  count    = "${var.instance_count}"
  template = "${file("${path.module}/node-user-data.tmpl")}"

  vars {
    teleport_version = "v2.7.4"
    app              = "${var.application_name}"
    nodename         = "${var.application_name}-${count.index}"
    cluster_token    = "${data.aws_secretsmanager_secret_version.cluster_token.secret_string}"
    auth_domain      = "teleport-auth.${var.name}.local"
  }
}

resource "aws_instance" "application" {
  count         = "${var.instance_count}"
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "${var.instance_size}"

  # iam_instance_profile = "${var.pubweb_instance_role}"
  user_data = "${element(data.template_file.user_data.*.rendered, count.index)}"
  key_name  = "infrastructure"

  associate_public_ip_address = false
  subnet_id                   = "${element(data.aws_subnet.application_subnet.*.id,count.index)}" #distribute instances across AZs
  vpc_security_group_ids      = ["${module.base.app_sg_id}"]

  lifecycle {
    ignore_changes = ["ami"]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags {
    Name = "${var.application_name}-${count.index}"
    app  = "${var.application_name}"
    env  = "${var.name}"
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
