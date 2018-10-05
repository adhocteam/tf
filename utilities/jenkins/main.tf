#######
# ALB that provides the public front for Jenkins
# It terminates TLS and redirects HTTP to HTTPS for secure access.
#######

resource "aws_alb" "jenkins" {
  name            = "jenkins-load-balancer"
  internal        = false
  security_groups = ["${aws_security_group.alb.id}"]

  subnets = [
    "subnet-3c00c665",
    "subnet-471c9d22",
  ]

  tags {
    Name = "jenkins-load-balancer"
    app  = "jenkins"
    role = "load-balancer"
  }
}

resource "aws_alb_target_group" "primary" {
  name     = "alb-jenkins-target"
  vpc_id   = "vpc-08b7136d"
  port     = "8080"
  protocol = "HTTP"

  health_check {
    path                = "/login"
    port                = "8080"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 5
    timeout             = 4
    matcher             = "200-308"
  }
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = "${aws_alb.jenkins.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.pizza_cert_wildcard.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.primary.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "redirect_to_https" {
  load_balancer_arn = "${aws_alb.jenkins.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Assign domain name
resource "aws_route53_record" "alb" {
  zone_id = "${var.route53_zone_id}"
  name    = "${var.domain_name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_alb.jenkins.dns_name}"]
}

# Security group
resource "aws_security_group" "alb" {
  name_prefix = "$jenkins-alb-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    app  = "jenkins"
    role = "alb"
  }
}

resource "aws_security_group_rule" "alb_tls" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.alb.id}"
}

resource "aws_security_group_rule" "alb_http" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.alb.id}"
}

resource "aws_security_group_rule" "alb_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

#######
### Jenkins primary instance that hosts Web UI
#######

resource "aws_instance" "jenkins_primary" {
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "t2.micro"
  key_name      = "infrastructure"

  tags {
    Name = "jenkins-primary"
    app  = "jenkins"
    role = "primary"
  }

  security_groups = ["${aws_security_group.jenkins_primary.id}"]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable --now docker
              docker run -d --restart always --name jenkins -p 8080:8080 -p 50000:50000 jskeets/jenkins-primary
              EOF

  lifecycle {
    ignore_changes = ["ami"]
  }
}

resource "aws_lb_target_group_attachment" "primary" {
  target_group_arn = "${aws_alb_target_group.primary.arn}"
  target_id        = "${aws_instance.jenkins_primary.id}"
  port             = 8080
}

resource "aws_security_group" "jenkins_primary" {
  name_prefix = "$jenkins-primary-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    app  = "jenkins"
    role = "primary"
  }
}

resource "aws_security_group_rule" "primary_ssh_ingress" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.jenkins_primary.id}"
}

resource "aws_security_group_rule" "alb_to_primary" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.alb.id}"

  security_group_id = "${aws_security_group.jenkins_primary.id}"
}


resource "aws_security_group_rule" "worker_to_primary_http" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.jenkins_worker.id}"

  security_group_id = "${aws_security_group.jenkins_primary.id}"
}

resource "aws_security_group_rule" "worker_to_primary_jnlp" {
  type                     = "ingress"
  from_port                = 50000
  to_port                  = 50000
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.jenkins_worker.id}"

  security_group_id = "${aws_security_group.jenkins_primary.id}"
}

resource "aws_security_group" "primary_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.jenkins_primary.id}"
}

#######
### Jenkins workers who actually execute the work
#######
resource "aws_instance" "jenkins_worker" {
  count         = "${var.num_workers}"
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "t2.micro"
  key_name      = "infrastructure"

  tags {
    Name = "jenkins-worker-${count.index}"
    app  = "jenkins"
    role = "worker"
  }

  security_groups = ["${aws_security_group.jenkins_worker.id}"]

  depends_on = ["aws_instance.jenkins_primary"]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable --now docker
              docker run --restart always csanchez/jenkins-swarm-slave -master "http://${aws_instance.jenkins_primary.private_ip}":8080 -username adhoc -password adhoc -executors "${var.num_executors}"
              EOF

  lifecycle {
    ignore_changes = ["ami"]
  }
}

resource "aws_security_group" "jenkins_worker" {
  name_prefix = "$jenkins-worker-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    app  = "jenkins"
    role = "worker"
  }
}

resource "aws_security_group_rule" "worker_ssh_ingress" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.jenkins_worker.id}"
}

resource "aws_security_group" "worker_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.jenkins_worker.id}"
}
