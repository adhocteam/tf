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
  name_prefix = "inhttp"
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
  name_prefix = "in-tls"
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

resource "aws_ecr_repository" "nginx" {
  name = "nginx-${var.env}"
}

resource "aws_instance" "nginx" {
  count         = 1
  ami           = "${data.aws_ami.base.id}"
  instance_type = "t3.medium"

  iam_instance_profile = "${aws_iam_instance_profile.iam.name}"

  user_data = <<EOF
#!/usr/bin/env bash
set -euo pipefail

eval $(aws ecr get-login --region=us-east-1 --no-include-email)

docker pull ${aws_ecr_repository.nginx.repository_url}:latest
docker run -d --restart=unless-stopped \
  --name nginx \
  -p 80:80 \
  -p 8080:8080 \
  ${aws_ecr_repository.nginx.repository_url}:latest
EOF

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

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = "${aws_iam_role.iam.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
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

#######
# DNS Records for proxied site
#######

resource "aws_route53_record" "external_cname" {
  zone_id = "${data.aws_route53_zone.external.id}"
  name    = "helloworld"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_lb.nlb.dns_name}"]
}

#######
# self-signed cert
#######

resource "tls_private_key" "example" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "example" {
  key_algorithm   = "${tls_private_key.example.algorithm}"
  private_key_pem = "${tls_private_key.example.private_key_pem}"

  # Certificate expires after 3 months
  validity_period_hours = 2190

  # Generate a new certificate if Terraform is run a week before
  early_renewal_hours = 168

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["helloworld.adhocdemo.com"]

  subject {
    common_name  = "helloworld.adhocdemo.com"
    organization = "Ad Hoc LLC"
  }
}

# For example, this can be used to populate an AWS IAM server certificate.
resource "aws_iam_server_certificate" "helloworld" {
  name             = "hello-world-self-signed-cert"
  certificate_body = "${tls_self_signed_cert.example.cert_pem}"
  private_key      = "${tls_private_key.example.private_key_pem}"
}

#######
# ALB with self-signed cert in front of HTTP service
#######

resource "aws_alb" "application_alb" {
  # max 6 characters for name prefix
  name_prefix     = "app-lb"
  internal        = false
  security_groups = ["${aws_security_group.application_alb_sg.id}"]
  subnets         = ["${data.aws_subnet.public.*.id}"]

  ip_address_type = "ipv4"

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "helloworld"
    name      = "alb-helloworld"
  }
}

resource "aws_alb_listener" "application_alb_https" {
  load_balancer_arn = "${aws_alb.application_alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${aws_iam_server_certificate.helloworld.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.application.arn}"
    type             = "forward"
  }
}

# Security Group: world -> alb
resource "aws_security_group" "application_alb_sg" {
  name_prefix = "app-alb-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "helloworld"
    name      = "world->alb-sg-helloworld"
  }
}

// Allow inbound only to our listening port
resource "aws_security_group_rule" "lb_ingress" {
  type        = "ingress"
  from_port   = "443"
  to_port     = "443"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.application_alb_sg.id}"
}

// Allow all outbound by default
resource "aws_security_group_rule" "lb_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.application_alb_sg.id}"
}

#######
# Web server
#######

resource "aws_instance" "application" {
  ami           = "${data.aws_ami.base.id}"
  instance_type = "t3.micro"

  user_data = <<EOF
#!/usr/bin/env bash
set -euo pipefail

docker run -d --restart=unless-stopped \
  --name nginx \
  -p 80:80 \
  nginxdemos/hello
EOF

  key_name = "infrastructure"

  associate_public_ip_address = false

  #distribute instances across AZs
  subnet_id              = "${element(data.aws_subnet.application.*.id,count.index)}"
  vpc_security_group_ids = ["${aws_security_group.app_sg.id}"]

  lifecycle {
    ignore_changes = ["ami"]
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags {
    Name = "helloworld-${count.index}"
    app  = "helloworld"
    env  = "${var.env}"
  }
}

resource "aws_alb_target_group" "application" {
  # max 6 characters for name prefix
  name_prefix = "app-lb"
  port        = "80"
  protocol    = "HTTP"
  vpc_id      = "${data.aws_vpc.vpc.id}"
  target_type = "ip"                     # Must use IP to support fargate

  health_check {
    interval            = 60
    path                = "/"
    port                = "80"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  depends_on = ["aws_alb.application_alb"]

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "helloworld"
    name      = "alb-tg-helloworld:80"
  }
}

resource "aws_alb_target_group_attachment" "application_targets" {
  target_group_arn = "${aws_alb_target_group.application.arn}"
  target_id        = "${aws_instance.application.private_ip}"
}

resource "aws_security_group" "app_sg" {
  name_prefix = "helloworld-app-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    app = "helloworld"
    env = "${var.env}"
  }
}

// Allow inbound only to our application port
resource "aws_security_group_rule" "app_ingress" {
  type                     = "ingress"
  from_port                = "80"
  to_port                  = "80"
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.application_alb_sg.id}"

  security_group_id = "${aws_security_group.app_sg.id}"
}

// Allow all outbound, e.g. third-pary API endpoints, by default
resource "aws_security_group_rule" "app_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.app_sg.id}"
}
