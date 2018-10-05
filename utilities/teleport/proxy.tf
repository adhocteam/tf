#######
# The proxy is what handles client connections from the internet and
# forwards to the private nodes. It also has a web interface.
# This is stateless and can horizontally scale behind the LB as needed
#######

#######
# Load balancer for web traffic
#######

resource "aws_elb" "proxy" {
  name_prefix     = "telep-"
  internal        = false
  security_groups = ["${aws_security_group.proxy_lb.id}"]
  subnets         = ["${data.aws_subnet.public_subnet.*.id}"]

  # Allow connections to idle for an hour
  idle_timeout = 3600

  listener {
    instance_port     = 3023
    instance_protocol = "tcp"
    lb_port           = 3023
    lb_protocol       = "tcp"
  }

  listener {
    instance_port      = 3080
    instance_protocol  = "tcp"
    lb_port            = 443
    lb_protocol        = "ssl"
    ssl_certificate_id = "${data.aws_acm_certificate.wildcard.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:3080/v1/webapi/ping"
    interval            = 30
  }

  tags {
    env       = "${var.name}"
    terraform = "true"
    app       = "teleport"
    name      = "elb-teleport-proxy"
  }
}

######
# Security groups for Load Balancer
#######

# Security Group: world -> proxy
resource "aws_security_group" "proxy_lb" {
  name_prefix = "teleport-proxy-lb-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    env       = "${var.name}"
    terraform = "true"
    app       = "teleport"
    Name      = "world->teleport-proxy"
  }
}

resource "aws_security_group_rule" "lb_webui_ingress" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.proxy_lb.id}"
}

resource "aws_security_group_rule" "lb_ssh_ingress" {
  type        = "ingress"
  from_port   = 3023
  to_port     = 3023
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.proxy_lb.id}"
}

resource "aws_security_group_rule" "lb_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.proxy_lb.id}"
}

#######
# Proxy instances
#######

# Must use template here to get ports as ints
data "template_file" "user_data" {
  count    = "${var.proxy_count}"
  template = "${file("${path.module}/proxy-user-data.tmpl")}"

  vars {
    teleport_version = "v2.7.4"
    nodename         = "teleport-proxy-${count.index}"
    cluster_token    = "${random_string.cluster_token.result}"
    auth_domain      = "${aws_route53_record.auth_internal.fqdn}"
    proxy_domain     = "${aws_route53_record.proxies_external.fqdn}"
  }
}

resource "aws_instance" "proxies" {
  count         = "${var.proxy_count}"
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "t3.micro"
  key_name      = "infrastructure"

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
    env       = "${var.name}"
    terraform = "true"
  }
}

# Add to target group to attach to LB

resource "aws_elb_attachment" "proxy_ssh" {
  count    = "${var.proxy_count}"
  elb      = "${aws_elb.proxy.id}"
  instance = "${element(aws_instance.proxies.*.id,count.index)}"
}

#######
### Security group for proxy instances
#######

resource "aws_security_group" "proxies" {
  name_prefix = "teleport-proxies-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    env       = "${var.name}"
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-proxies"
  }
}

resource "aws_security_group_rule" "proxy_webui" {
  type                     = "ingress"
  from_port                = 3080
  to_port                  = 3080
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.proxy_lb.id}"

  security_group_id = "${aws_security_group.proxies.id}"
}

resource "aws_security_group_rule" "proxy_ssh" {
  type                     = "ingress"
  from_port                = 3023
  to_port                  = 3023
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.proxy_lb.id}"

  security_group_id = "${aws_security_group.proxies.id}"
}

# Must allow talking to the world to pull down teleport binaries (for now)
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
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.jumpbox.id}"

  security_group_id = "${aws_security_group.proxies.id}"
}
