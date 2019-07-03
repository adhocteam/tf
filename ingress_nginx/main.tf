#######
# DNS Records for proxied site(s)
#######

terraform {
  required_version = ">= 0.12"
}

module "alb" {
  source = "../ingress"

  base         = var.base
  applications = var.applications
  nginx        = true
}


resource "aws_route53_record" "external" {
  count   = length(var.applications)
  zone_id = var.base.external.id
  name    = var.applications[count.index].name
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
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = local.target_groups["80"].arn
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
    target_group_arn = local.target_groups["443"].arn
  }
}
