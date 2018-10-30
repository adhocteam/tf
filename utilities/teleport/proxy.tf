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
    ssl_certificate_id = "${module.cert.arn}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:3080/v1/webapi/ping"
    interval            = 30
  }

  tags {
    env       = "${var.env}"
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
    env       = "${var.env}"
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

  iam_instance_profile = "${aws_iam_instance_profile.proxy.name}"
  user_data            = "${element(data.template_file.user_data.*.rendered, count.index)}"

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
    env       = "${var.env}"
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

# Must allow talking to the world to call out to AWS APIs
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
  source_security_group_id = "${var.jumpbox_sg}"

  security_group_id = "${aws_security_group.proxies.id}"
}

#######
# IAM accesses for the instance
#######

resource "aws_iam_instance_profile" "proxy" {
  name = "${var.env}-teleport-proxy"
  role = "${aws_iam_role.proxy.name}"
}

// Auth instance profile and roles
resource "aws_iam_role" "proxy" {
  name = "${var.env}-teleport-proxy"

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
resource "aws_iam_role_policy_attachment" "proxy_teleport" {
  role       = "${aws_iam_role.proxy.name}"
  policy_arn = "${aws_iam_policy.teleport_secrets.arn}"
}
