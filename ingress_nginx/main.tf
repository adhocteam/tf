#######
# DNS Records for proxied site(s)
#######

terraform {
  required_version = ">= 0.12"
}

module "alb" {
  source = "../ingress"

  base         = base
  applications = applications
  nginx        = true
}


resource "aws_route53_record" "external" {
  count   = length(var.applications)
  zone_id = var.base.external.id
  name    = var.applications[count.index].name
  type    = "CNAME"
  ttl     = 30

  records = [aws_alb.ingress.dns_name]
}


#######
# Network load balancer that receives traffic from the internet
# Terminates our TLS for HTTPS traffic
#######

resource "aws_lb" "nlb" {
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
