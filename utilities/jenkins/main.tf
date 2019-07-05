#######
# ALB that provides the public front for Jenkins
# It terminates TLS and redirects HTTP to HTTPS for secure access.
#######
terraform {
  required_version = ">= 0.12"
}

locals {
  url = "jenkins.${var.base.domain_name}"
}

# resource "aws_alb" "jenkins" {
#   name            = "jenkins-load-balancer"
#   internal        = false
#   security_groups = [aws_security_group.alb.id]
#   subnets         = s_subnet.public_subnet.*.id

#   tags = {
#     env       = var.env
#     terraform = "true"
#     Name      = "jenkins-load-balancer"
#     app       = "jenkins"
#   }
# }

# resource "aws_alb_target_group" "primary" {
#   name     = "alb-jenkins-target"
#   vpc_id   = data.aws_vpc.vpc.id
#   port     = "8080"
#   protocol = "HTTP"

#   health_check {
#     path                = "/login"
#     port                = "8080"
#     protocol            = "HTTP"
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     interval            = 5
#     timeout             = 4
#     matcher             = "200-308"
#   }

#   tags = {
#     env       = var.env
#     terraform = "true"
#     Name      = "jenkins-load-balancer"
#     app       = "jenkins"
#   }
# }

# resource "aws_lb_listener" "redirect_to_https" {
#   load_balancer_arn = aws_alb.jenkins.arn
#   port              = "80"
#   protocol          = "HTTP"

#   default_action {
#     type = "redirect"

#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

# # Assign domain name
# resource "aws_route53_record" "alb" {
#   zone_id = data.aws_route53_zone.external.id
#   name    = local.url
#   type    = "CNAME"
#   ttl     = 30

#   records = [aws_alb.jenkins.dns_name]
# }

# resource "aws_alb_listener" "https" {
#   load_balancer_arn = aws_alb.jenkins.arn
#   port              = "443"
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = data.aws_acm_certificate.wildcard.arn

#   default_action {
#     target_group_arn = aws_alb_target_group.primary.arn
#     type             = "forward"
#   }
# }

# Security group
# resource "aws_security_group" "alb" {
#   name_prefix = "$jenkins-alb-"
#   vpc_id      = data.aws_vpc.vpc.id

#   tags = {
#     env       = var.env
#     terraform = "true"
#     app       = "jenkins"
#     role      = "alb"
#   }
# }

# resource "aws_security_group_rule" "alb_tls" {
#   type        = "ingress"
#   from_port   = 443
#   to_port     = 443
#   protocol    = "tcp"
#   cidr_blocks = ["0.0.0.0/0"]

#   security_group_id = aws_security_group.alb.id
# }

# resource "aws_security_group_rule" "alb_http" {
#   type        = "ingress"
#   from_port   = 80
#   to_port     = 80
#   protocol    = "tcp"
#   cidr_blocks = ["0.0.0.0/0"]

#   security_group_id = aws_security_group.alb.id
# }

# resource "aws_security_group_rule" "alb_egress" {
#   type        = "egress"
#   from_port   = 0
#   to_port     = 0
#   protocol    = "-1"
#   cidr_blocks = ["0.0.0.0/0"]

#   security_group_id = aws_security_group.alb.id
# }

#######
### Jenkins primary instance that hosts Web UI
#######
module "primary" {
  source = "../../instance"

  base             = var.base
  instance_size    = "t3.small"
  application_name = "jenkins-primary"
  user_data = templatefile("${path.module}/primary.tmpl", {
    github_client_id     = "${data.aws_secretsmanager_secret_version.github_client_id.secret_string}"
    github_client_secret = "${data.aws_secretsmanager_secret_version.github_client_secret.secret_string}"
    jenkins_url          = "https://${local.url}"
    github_user          = "${var.github_user}"
    github_password      = "${data.aws_secretsmanager_secret_version.github_password.secret_string}"
    docker_user          = "${var.docker_user}"
    docker_password      = "${data.aws_secretsmanager_secret_version.docker_password.secret_string}"
    slack_token          = "${data.aws_secretsmanager_secret_version.slack_token.secret_string}"
    jenkins_image        = "adhocteam/jenkins:${var.image_tag}"
  })
}

# Convenient internal DNS name for other items in VPC to use if needed
resource "aws_route53_record" "primary" {
  zone_id = var.base.vpc.internal_dns.zone_id
  name    = "primary.jenkins"
  type    = "CNAME"
  ttl     = 30

  records = [module.primary.instances[0].private_dns]
}

resource "aws_security_group_rule" "worker_to_primary_jnlp" {
  type                     = "ingress"
  from_port                = 50000
  to_port                  = 50000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.worker.id

  security_group_id = module.primary.security_group.id
}

# resource "aws_lb_target_group_attachment" "primary" {
#   target_group_arn = aws_alb_target_group.primary.arn
#   target_id        = aws_instance.jenkins_primary.id
#   port             = 8080
# }

# resource "aws_security_group_rule" "alb_to_primary" {
#   type                     = "ingress"
#   from_port                = 8080
#   to_port                  = 8080
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.alb.id

#   security_group_id = aws_security_group.jenkins_primary.id
# }

# resource "aws_security_group_rule" "worker_to_primary_http" {
#   type                     = "ingress"
#   from_port                = 8080
#   to_port                  = 8080
#   protocol                 = "tcp"
#   source_security_group_id = aws_security_group.jenkins_worker.id

#   security_group_id = aws_security_group.jenkins_primary.id
# }

#######
### Jenkins workers who actually execute the work
#######

# Can't use the module because we have to vary the instance types
resource "aws_instance" "jenkins_worker" {
  count         = length(var.workers)
  ami           = var.base.ami.id
  instance_type = var.workers[count.index].instance_type
  key_name      = var.base.ssh_key

  iam_instance_profile = aws_iam_instance_profile.worker.name

  user_data = templatefile("${path.module}/worker.tmpl", {
    count     = count.index
    master    = "http://${aws_route53_record.primary.fqdn}:8080"
    label     = var.workers[count.index].label
    username  = var.github_user
    password  = data.aws_secretsmanager_secret_version.github_password.secret_string
    executors = var.workers[count.index].executors
  })

  associate_public_ip_address = false
  subnet_id                   = var.base.vpc.application[count.index].id #distribute workers across AZs
  vpc_security_group_ids = [
    var.base.security_groups["teleport_nodes"].id,
    var.base.security_groups["jumpbox_nodes"].id,
    aws_security_group.worker.id
  ]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 120
    delete_on_termination = true
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    Name      = "jenkins-${var.workers[count.index].label}-${count.index}"
    app       = "jenkins"
    label     = var.workers[count.index].label
    role      = "worker"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Internal DNS references to each worker node
resource "aws_route53_record" "worker" {
  count   = length(var.workers)
  zone_id = var.base.vpc.internal_dns.zone_id
  name    = "${var.workers[count.index].label}-${count.index}.jenkins"
  type    = "CNAME"
  ttl     = 30

  records = [aws_instance.jenkins_worker[count.index].private_dns]
}

resource "aws_security_group" "worker" {
  name_prefix = "$jenkins-worker-"
  vpc_id      = var.base.vpc.id

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "jenkins"
    role      = "worker"
  }
}

resource "aws_security_group_rule" "worker_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.worker.id
}

#######
# IAM accesses
#######

### Worker
resource "aws_iam_instance_profile" "worker" {
  name = "${var.base.env}-jenkins-worker"
  role = aws_iam_role.worker.name
}

# Auth instance profile and roles
resource "aws_iam_role" "worker" {
  name = "${var.base.env}-jenkins-worker"

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
resource "aws_iam_role_policy_attachment" "iam_teleport" {
  role = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::${var.base.account.account_id}:policy/${var.base.env}/teleport/${var.base.env}-instance-teleport-secrets"
}

