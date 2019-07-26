#######
# DNS Records for proxied site(s)
#######

terraform {
  required_version = ">= 0.12"
}

resource "aws_route53_record" "ingress" {
  zone_id = var.base.external.id
  name    = "ingress-${var.base.env}"
  type    = "CNAME"
  ttl     = 30

  records = [aws_lb.nlb.dns_name]
}

#######
# Network load balancer that receives traffic from the internet
# Terminates our TLS for HTTPS traffic
#######

resource "aws_lb" "nlb" {
  name_prefix        = "in-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.base.vpc.public[*].id

  enable_cross_zone_load_balancing = true

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "ingress"
    Name      = "ingress-nlb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_target_group" "http" {
  # max 6 characters for name prefix
  name_prefix = "ingres"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.base.vpc.id
  target_type = "ip" # Must use IP to support fargate

  health_check {
    interval            = 60
    path                = "/"
    port                = 200
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "ingress-nginx"
    name      = "ingress-nginx-http"
  }
}

resource "aws_lb_listener" "https" {
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
  # max 6 characters for name prefix
  name_prefix = "ingres"
  port        = 443
  protocol    = "TLS"
  vpc_id      = var.base.vpc.id
  target_type = "ip" # Must use IP to support fargate

  health_check {
    interval            = 60
    path                = "/"
    port                = 200
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "ingress-nginx"
    name      = "ingress-nginx-https"
  }
}
