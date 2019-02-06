#######
# The proxy is what handles client connections from the main cluster and
# forwards to the private nodes.
# This is stateless and can horizontally scale.
#######

#######
# Proxy instances
#######
data "template_file" "user_data" {
  count    = "${var.proxy_count}"
  template = "${file("${path.module}/proxy-user-data.tmpl")}"

  vars {
    nodename      = "teleport-proxy-${count.index}"
    cluster_token = "${random_string.cluster_token.result}"
    proxy_domain  = "${aws_route53_record.public.fqdn}"
  }
}

resource "aws_instance" "proxies" {
  count         = "${var.proxy_count}"
  ami           = "${data.aws_ami.base.id}"
  instance_type = "t3.micro"
  key_name      = "${var.key_pair}"

  user_data = "${element(data.template_file.user_data.*.rendered, count.index)}"

  associate_public_ip_address = false
  subnet_id                   = "${element(data.aws_subnet.application_subnet.*.id,count.index)}" #distribute instances across AZs
  vpc_security_group_ids      = ["${aws_security_group.proxies.id}"]

  lifecycle {
    ignore_changes = ["ami"]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags {
    Name      = "teleport-proxy-${count.index}"
    app       = "teleport"
    env       = "${var.env}"
    terraform = "true"
  }
}

#######
### Security group for proxy instances
#######

resource "aws_security_group" "proxies" {
  name_prefix = "teleport-proxies-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-proxies"
  }
}

# Must allow talking to the world to call out to AWS APIs
# and main cluster
resource "aws_security_group_rule" "proxy_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.proxies.id}"
}

# Support for emergency jumpbox
resource "aws_security_group_rule" "jumpbox_proxy" {
  count                    = "${var.jumpbox_sg != "" ? 1 : 0}"
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${var.jumpbox_sg}"

  security_group_id = "${aws_security_group.proxies.id}"
}
