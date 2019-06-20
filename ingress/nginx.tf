#######
# Nginx Reverse Proxy to send data to our backends
# Controlled by var.nginx on if these are used or not
#######

#######
# Network load balancer that receives traffic from the internet
# Terminates our TLS for HTTPS traffic
#######
locals {
  enabled = var.nginx ? 1 : 0
}

resource "aws_lb" "nlb" {
  count              = local.enabled
  name_prefix        = "in-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.base.vpc.public[*]

  enable_cross_zone_load_balancing = true

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "ingress"
    Name      = "ingress-nlb"
  }
}

resource "aws_lb_listener" "http" {
  count             = local.enabled
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_target_group" "http" {
  count       = local.enabled
  name_prefix = "inhttp"
  port        = "80"
  protocol    = "TCP"
  vpc_id      = var.base.vpc.id

  target_type = "ip"

  health_check {
    protocol = "TCP"
    port     = 200
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "ingress"
    Name      = "ingress-nlb-http"
  }
}

resource "aws_lb_listener" "https" {
  count             = local.enabled
  load_balancer_arn = aws_lb.nlb.arn
  port              = "443"
  protocol          = "TLS"

  ssl_policy      = "ELBSecurityPolicy-FS-2018-06"
  certificate_arn = var.base.wildcard.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

resource "aws_lb_target_group" "https" {
  count       = local.enabled
  name_prefix = "in-tls"
  port        = "443"
  protocol    = "TLS"
  vpc_id      = var.base.vpc.id

  # Use IP to support Fargate clusters
  target_type = "ip"

  # Enable proxy protocol to get original source IP
  proxy_protocol_v2 = true

  health_check {
    protocol = "TCP"
    port     = 200
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "ingress"
    Name      = "ingress-nlb-https"
  }
}


# Create ECR repo for docker image and provide cross account access if needed
resource "aws_ecr_repository" "nginx" {
  name = "ingress-${var.base.env}"
}

resource "aws_ecr_repository_policy" "cross_account_access" {
  count      = length(var.other_accounts)
  repository = aws_ecr_repository.nginx.name

  policy = local.cross_account_policy

}

data "aws_iam_policy_document" "cross_account_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.other_accounts
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cross_account_assume_role" {
  name               = "ingress-cross-account-${var.base.env}"
  assume_role_policy = data.aws_iam_policy_document.cross_account_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cross_account_assume_role" {
  role       = aws_iam_role.cross_account_assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}

module "nginx" {
  source = "../fargate_cluster"

  base             = var.base
  application_name = "nginx_ingress"
  docker_image     = "${aws_ecr_repository.nginx.repository_url}:latest"
}
#,, Create the hosts for nginx
resource "aws_instance" "nginx" {
  count         = 1
  ami           = var.base.ami.id
  instance_type = "t3.medium"

  iam_instance_profile = aws_iam_instance_profile.iam.name

  #user_data = <<EOF
  ##!/usr/bin/env bash
  #set -euo pipefail

  #eval $(aws ecr get-login --region=us-east-1 --no-include-email)

  #docker pull ${aws_ecr_repository.nginx.repository_url}:latest
  #docker run -d --restart=unless-stopped \
  #--name nginx \
  #-p 80:80 \
  #-p 200:200 \
  #-p 443:443 \
  #${aws_ecr_repository.nginx.repository_url}:latest

  #EOF
}

# Security group for nginx
resource "aws_security_group" "nginx" {
  name_prefix = "ingress-nginx-"
  vpc_id      = var.base.vpc.id

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "ingress-nginx"
    Name      = "ingress-nginx"
  }
}

#TODO(bob) this may be able to be restricted to our private CIDR b/c we use proxy_protocol
resource "aws_security_group_rule" "nginx_http" {
  type        = "ingress"
  from_port   = "80"
  to_port     = "80"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.nginx.id
}

resource "aws_security_group_rule" "nginx_https" {
  type        = "ingress"
  from_port   = "443"
  to_port     = "443"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.nginx.id
}

resource "aws_security_group_rule" "nginx_healthcheck" {
  type        = "ingress"
  from_port   = "200"
  to_port     = "200"
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.nginx.id
}

resource "aws_security_group_rule" "nginx_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.nginx.id
}

resource "aws_alb_target_group_attachment" "nginx" {
  count            = local.enabled
  target_group_arn = local.nlb_target_groups[count.index].arn
  target_id        = aws_instance.box[count.index].private_ip
}

locals {
  cross_account_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.other_accounts[count.index]}:root"
      },
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories"
      ]
    }
  ]
}
EOF

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
