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
  name    = "jenkins.${var.env}"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_alb.jenkins.dns_name}"]
}

module "cert" {
  source = "../../wildcard_cert"

  env         = "${var.env}"
  root_domain = "${var.domain_name}"
  domain      = "${aws_route53_record.alb.fqdn}"
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
  instance_type = "t2.micro"
  key_name      = "infrastructure"

  associate_public_ip_address = false
  subnet_id                   = "${element(data.aws_subnet.application_subnet.*.id,1)}"
  vpc_security_group_ids      = ["${aws_security_group.jenkins_primary.id}"]

  iam_instance_profile = "${aws_iam_instance_profile.primary.name}"

  user_data = <<-EOF
              #!/bin/bash
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
resource "aws_instance" "jenkins_worker" {
  count                = "${var.num_workers}"
  ami                  = "${data.aws_ami.base.id}"
  instance_type        = "t2.micro"
  key_name             = "infrastructure"
  iam_instance_profile = "${aws_iam_instance_profile.worker.name}"

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
  key_id            = "${data.aws_kms_alias.main.target_key.arn}"
  grantee_principal = "${aws_iam_role.primary.arn}"
  operations        = ["Decrypt"]
}

resource "aws_kms_grant" "worker" {
  name              = "jenkins-worker-main"
  key_id            = "${data.aws_kms_alias.main.target_key.arn}"
  grantee_principal = "${aws_iam_role.worker.arn}"
  operations        = ["Decrypt"]
}
