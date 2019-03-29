#######
# Network load balancer that receives traffic from the internet
# Terminates our TLS for HTTPS traffic
#######

resource "aws_lb" "nlb" {
  name_prefix        = "in-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["${data.aws_subnet.public.*.id}"]

  enable_cross_zone_load_balancing = true

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "ingress"
    Name      = "ingress-nlb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.nlb.arn}"
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.http.arn}"
  }
}

resource "aws_lb_target_group" "http" {
  name_prefix = "in_http"
  port        = "80"
  protocol    = "TCP"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  target_type = "ip"

  health_check = {
    protocol = "TCP"
  }

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "ingress"
    Name      = "ingress-nlb-http"
  }
}

# TODO
resource "aws_lb_listener" "https" {
  load_balancer_arn = "${aws_lb.nlb.arn}"
  port              = "443"
  protocol          = "TLS"

  ssl_policy      = "ELBSecurityPolicy-FS-2018-06"
  certificate_arn = "${data.aws_acm_certificate.wildcard.arn}"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.https.arn}"
  }
}

resource "aws_lb_target_group" "https" {
  name_prefix = "in_https"
  port        = "8080"
  protocol    = "TCP"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  # Use IP to support Fargate clusters
  target_type = "ip"

  # Enable proxy protocol to get original source IP
  proxy_protocol_v2 = true

  health_check = {
    protocol = "TCP"
  }

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "ingress"
    Name      = "ingress-nlb-https"
  }
}

resource "aws_alb_target_group_attachment" "http" {
  count            = 1
  target_group_arn = "${aws_lb_target_group.http.arn}"
  target_id        = "${element(aws_instance.nginx.*.private_ip, count.index)}"
}

resource "aws_alb_target_group_attachment" "https" {
  count            = 1
  target_group_arn = "${aws_lb_target_group.https.arn}"
  target_id        = "${element(aws_instance.nginx.*.private_ip, count.index)}"
}

#######
# Nginx Reverse Proxy to send data to our backends
#######

resource "aws_instance" "nginx" {
  count         = 1
  ami           = "${data.aws_ami.base.id}"
  instance_type = "t3.medium"

  iam_instance_profile = "${aws_iam_instance_profile.iam.name}"

  #user_data            = "${var.user_data}"
  key_name = "infrastructure"

  associate_public_ip_address = false

  #distribute instances across AZs
  subnet_id              = "${element(data.aws_subnet.application.*.id,count.index)}"
  vpc_security_group_ids = ["${aws_security_group.nginx.id}"]

  lifecycle {
    ignore_changes = ["ami"]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags {
    Name      = "ingress-nginx"
    terraform = "true"
    app       = "ingress"
    env       = "${var.env}"
  }
}

# Security group for nginx
resource "aws_security_group" "nginx" {
  name_prefix = "ingress-nginx-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "ingress-nginx"
    Name      = "ingress-nginx"
  }
}

resource "aws_security_group_rule" "nginx_http" {
  type        = "ingress"
  from_port   = "80"
  to_port     = "80"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.nginx.id}"
}

resource "aws_security_group_rule" "nginx_https" {
  type        = "ingress"
  from_port   = "8080"
  to_port     = "8080"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.nginx.id}"
}

resource "aws_security_group_rule" "nginx_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.nginx.id}"
}

# Base IAM instance profile
resource "aws_iam_instance_profile" "iam" {
  name = "${var.env}-ingress-nginx"
  role = "${aws_iam_role.iam.name}"
}

# Auth instance profile and roles
resource "aws_iam_role" "iam" {
  name = "${var.env}-ingress-nginx"

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
# resource "aws_iam_role_policy_attachment" "iam_teleport" {
#   role       = "${aws_iam_role.iam.name}"
#   policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${var.env}/teleport/${var.env}-instance-teleport-secrets"
# }

resource "aws_kms_grant" "main" {
  name              = "${var.env}-ingress-nginx-main"
  key_id            = "${data.aws_kms_alias.main.target_key_arn}"
  grantee_principal = "${aws_iam_role.iam.arn}"
  operations        = ["Decrypt"]
}
