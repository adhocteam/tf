#######
# ALB that provides the public front for Jenkins
# It terminates TLS and redirects HTTP to HTTPS for secure access.
#######

resource "aws_alb" "jenkins" {
  name            = "jenkins-load-balancer"
  internal        = false
  security_groups = ["${aws_security_group.alb.id}"]
  subnets         = ["${data.aws_subnet.public_subnet.*.id}"]

  tags {
    env       = "${var.env}"
    terraform = "true"
    Name      = "jenkins-load-balancer"
    app       = "jenkins"
  }
}

resource "aws_alb_target_group" "primary" {
  name     = "alb-jenkins-target"
  vpc_id   = "${data.aws_vpc.vpc.id}"
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

  tags {
    env       = "${var.env}"
    terraform = "true"
    Name      = "jenkins-load-balancer"
    app       = "jenkins"
  }
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = "${aws_alb.jenkins.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${data.aws_acm_certificate.wildcard.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.primary.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "redirect_to_https" {
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
  zone_id = "${data.aws_route53_zone.external.id}"
  name    = "jenkins"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_alb.jenkins.dns_name}"]
}

# Security group
resource "aws_security_group" "alb" {
  name_prefix = "$jenkins-alb-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "jenkins"
    role      = "alb"
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

  security_group_id = "${aws_security_group.alb.id}"
}

#######
### Jenkins primary instance that hosts Web UI
#######

resource "aws_instance" "jenkins_primary" {
  ami           = "${data.aws_ami.amazon_linux_2.id}"
  instance_type = "t2.micro"
  key_name      = "infrastructure"

  associate_public_ip_address = false
  subnet_id                   = "${element(data.aws_subnet.application_subnet.*.id,1)}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_primary.id}"]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable --now docker
              docker run -d --restart always \
                --name jenkins \
                -p 8080:8080 \
                -p 50000:50000 \
                jskeets/jenkins-primary
              EOF

  lifecycle {
    ignore_changes = ["ami"]
  }

  tags {
    env       = "${var.env}"
    terraform = "true"
    Name      = "jenkins-primary"
    app       = "jenkins"
    role      = "primary"
  }
}

# Convenient internal DNS name for other items in VPC to use if needed
resource "aws_route53_record" "primary" {
  zone_id = "${data.aws_route53_zone.internal.id}"
  name    = "primary.jenkins"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_instance.jenkins_primary.private_dns}"]
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
    env       = "${var.env}"
    terraform = "true"
    app       = "jenkins"
    role      = "primary"
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

resource "aws_security_group_rule" "primary_egress" {
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
  count                = "${var.num_workers}"
  ami                  = "${data.aws_ami.amazon_linux_2.id}"
  instance_type        = "t2.micro"
  key_name             = "infrastructure"
  iam_instance_profile = "${var.worker_iam_profile}"

  associate_public_ip_address = false
  subnet_id                   = "${element(data.aws_subnet.application_subnet.*.id,count.index)}" #distribute instances across AZs
  vpc_security_group_ids      = ["${aws_security_group.jenkins_worker.id}"]

  tags {
    env       = "${var.env}"
    terraform = "true"
    Name      = "jenkins-worker-${count.index}"
    app       = "jenkins"
    role      = "worker"
  }

  depends_on = ["aws_instance.jenkins_primary"]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl enable --now docker
              docker run --restart always \
                -v /var/run/docker.sock:/var/run/docker.sock \
                csanchez/jenkins-swarm-slave -master "http://${aws_instance.jenkins_primary.private_ip}":8080 -username adhoc -password adhoc -executors "${var.num_executors}"
              EOF

  lifecycle {
    ignore_changes = ["ami"]
  }
}

# Internal DNS references to each worker node
resource "aws_route53_record" "worker" {
  count   = "${var.num_workers}"
  zone_id = "${data.aws_route53_zone.internal.id}"
  name    = "worker-${count.index}.jenkins"
  type    = "CNAME"
  ttl     = 30

  records = ["${element(aws_instance.jenkins_worker.*.private_dns, count.index)}"]
}

resource "aws_security_group" "jenkins_worker" {
  name_prefix = "$jenkins-worker-"
  vpc_id      = "${data.aws_vpc.vpc.id}"

  tags {
    env       = "${var.env}"
    terraform = "true"
    app       = "jenkins"
    role      = "worker"
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

resource "aws_security_group_rule" "worker_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.jenkins_worker.id}"
}
