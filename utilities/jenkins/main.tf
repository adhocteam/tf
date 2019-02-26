#######
# ALB that provides the public front for Jenkins
# It terminates TLS and redirects HTTP to HTTPS for secure access.
#######

locals {
  default_url = "jenkins.${var.env}.${var.domain_name}"
  url         = "${coalesce(var.jenkins_url, local.default_url)}"
}

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
  name    = "${local.url}"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_alb.jenkins.dns_name}"]
}

module "cert" {
  source = "../../wildcard_cert"

  env         = "${var.env}"
  root_domain = "${var.domain_name}"
  domain      = "${local.default_url}"
}

resource "aws_alb_listener" "https" {
  load_balancer_arn = "${aws_alb.jenkins.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${module.cert.arn}"

  default_action {
    target_group_arn = "${aws_alb_target_group.primary.arn}"
    type             = "forward"
  }
}

# Also allow it serve direct subdomains like jenkins.domain_name
resource "aws_alb_listener_certificate" "domain_name" {
  listener_arn    = "${aws_alb_listener.https.arn}"
  certificate_arn = "${data.aws_acm_certificate.wildcard.arn}"
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
  ami           = "${data.aws_ami.base.id}"
  instance_type = "t3.small"
  key_name      = "infrastructure"

  associate_public_ip_address = false
  subnet_id                   = "${element(data.aws_subnet.application_subnet.*.id,1)}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_primary.id}"]

  iam_instance_profile = "${aws_iam_instance_profile.primary.name}"

  user_data = <<-EOF
              #!/usr/bin/env bash
              docker run -d --restart always \
                -v jenkins_home:/var/jenkins_home \
                --name jenkins \
                -p 8080:8080 \
                -p 50000:50000 \
                -e github_client_id="${data.aws_secretsmanager_secret_version.github_client_id.secret_string}" \
                -e github_client_secret="${data.aws_secretsmanager_secret_version.github_client_secret.secret_string}" \
                -e jenkins_url="https://${local.url}" \
                -e github_user="${var.github_user}" \
                -e github_password="${data.aws_secretsmanager_secret_version.github_password.secret_string}" \
                -e docker_user="${var.docker_user}" \
                -e docker_password="${data.aws_secretsmanager_secret_version.docker_password.secret_string}" \
                -e slack_token="${data.aws_secretsmanager_secret_version.slack_token.secret_string}" \
                adhocteam/jenkins:latest
              EOF

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true
  }

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

resource "aws_security_group_rule" "primary_proxy_ssh" {
  type                     = "ingress"
  from_port                = 3022
  to_port                  = 3022
  protocol                 = "tcp"
  source_security_group_id = "${var.ssh_proxy_sg}"

  security_group_id = "${aws_security_group.jenkins_primary.id}"
}

resource "aws_security_group_rule" "primary_ssh_ingress" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${var.jumpbox_sg}"

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

data "template_file" "jenkins_worker" {
  count    = "${length(var.workers)}"
  template = "${file("${path.module}/worker.tmpl")}"

  vars {
    count     = "${count.index}"
    master    = "http://${aws_route53_record.primary.fqdn}:8080"
    label     = "${element(split(",", element(var.workers, count.index)), 0)}"
    username  = "${var.github_user}"
    password  = "${data.aws_secretsmanager_secret_version.github_password.secret_string}"
    executors = "${element(split(",", element(var.workers, count.index)), 2)}"
  }
}

resource "aws_instance" "jenkins_worker" {
  count         = "${length(var.workers)}"
  ami           = "${data.aws_ami.base.id}"
  instance_type = "${element(split(",", element(var.workers, count.index)), 1)}"
  key_name      = "infrastructure"

  iam_instance_profile = "${aws_iam_instance_profile.worker.name}"
  user_data            = "${element(data.template_file.jenkins_worker.*.rendered, count.index)}"

  associate_public_ip_address = false
  subnet_id                   = "${element(data.aws_subnet.application_subnet.*.id,count.index)}" #distribute workers across AZs
  vpc_security_group_ids      = ["${aws_security_group.jenkins_worker.id}"]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 40
    delete_on_termination = true
  }

  tags {
    env       = "${var.env}"
    terraform = "true"
    Name      = "jenkins-${element(split(",", element(var.workers, count.index)), 0)}-${count.index}"
    app       = "jenkins"
    label     = "${element(split(",", element(var.workers, count.index)), 0)}"
    role      = "worker"
  }

  depends_on = ["aws_instance.jenkins_primary"]

  lifecycle {
    ignore_changes = ["ami"]
  }
}

# Internal DNS references to each worker node
resource "aws_route53_record" "worker" {
  count   = "${length(var.workers)}"
  zone_id = "${data.aws_route53_zone.internal.id}"
  name    = "${element(split(",", element(var.workers, count.index)), 0)}-${count.index}.jenkins"
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

resource "aws_security_group_rule" "worker_proxy_ssh" {
  type                     = "ingress"
  from_port                = 3022
  to_port                  = 3022
  protocol                 = "tcp"
  source_security_group_id = "${var.ssh_proxy_sg}"

  security_group_id = "${aws_security_group.jenkins_worker.id}"
}

resource "aws_security_group_rule" "worker_ssh_ingress" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = "${var.jumpbox_sg}"

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

#######
# IAM accesses
#######

### Primary
resource "aws_iam_instance_profile" "primary" {
  name = "${var.env}-jenkins-primary"
  role = "${aws_iam_role.primary.name}"
}

# Auth instance profile and roles
resource "aws_iam_role" "primary" {
  name = "${var.env}-jenkins-primary"

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
resource "aws_iam_role_policy_attachment" "primary_teleport" {
  role       = "${aws_iam_role.primary.name}"
  policy_arn = "${aws_iam_policy.teleport_secrets.arn}"
}

### Worker
resource "aws_iam_instance_profile" "worker" {
  name = "${var.env}-jenkins-worker"
  role = "${aws_iam_role.worker.name}"
}

# Auth instance profile and roles
resource "aws_iam_role" "worker" {
  name = "${var.env}-jenkins-worker"

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
resource "aws_iam_role_policy_attachment" "worker_teleport" {
  role       = "${aws_iam_role.worker.name}"
  policy_arn = "${aws_iam_policy.teleport_secrets.arn}"
}

### Shared IAM role for teleport
resource "aws_iam_policy" "teleport_secrets" {
  name        = "jenkins-teleport-secrets"
  path        = "/${var.env}/jenkins/"
  description = "Allows nodes to run local teleport daemon"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect" : "Allow",
            "Action" : "ec2:DescribeTags",
            "Resource" : "*"
        },
        {
            "Effect": "Allow",
            "Action": "secretsmanager:GetSecretValue",
            "Resource": "${data.aws_secretsmanager_secret.cluster_token.arn}"
        },
        {
            "Effect": "Allow",
            "Action": "kms:Decrypt",
            "Resource": "${data.aws_kms_alias.main.target_key_arn}"
        }
    ]
}
EOF
}

resource "aws_kms_grant" "primary" {
  name              = "jenkins-primary-main"
  key_id            = "${data.aws_kms_alias.main.target_key_arn}"
  grantee_principal = "${aws_iam_role.primary.arn}"
  operations        = ["Decrypt"]
}

resource "aws_kms_grant" "worker" {
  name              = "jenkins-worker-main"
  key_id            = "${data.aws_kms_alias.main.target_key_arn}"
  grantee_principal = "${aws_iam_role.worker.arn}"
  operations        = ["Decrypt"]
}
