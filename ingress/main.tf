#######
# DNS Records for proxied site(s)
#######

terraform {
  required_version = ">= 0.12"
}

resource "aws_route53_record" "ingress" {
  count   = var.public ? 1 : 0
  zone_id = var.external_dns.id
  name    = "ingress-${var.env}"
  type    = "CNAME"
  ttl     = 30

  records = [aws_alb.ingress.dns_name]
}


#######
# ALB in front of HTTP services
#######

resource "aws_route53_record" "alb_cname" {
  zone_id = var.internal_dns.zone_id
  name    = "ingress-alb"
  type    = "CNAME"
  ttl     = 30

  records = [aws_alb.ingress.dns_name]
}

resource "aws_alb" "ingress" {
  # max 6 characters for name prefix
  name_prefix     = "in-alb"
  internal        = ! var.public
  security_groups = [aws_security_group.alb.id]
  subnets         = var.public ? var.subnet_ids.public : var.subnet_ids.application

  ip_address_type = "ipv4"

  tags = {
    env       = var.env
    terraform = "true"
    app       = "ingress"
    name      = "alb-ingress"
  }
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener" "http_to_https" {
  load_balancer_arn = aws_alb.ingress.arn
  port              = 80
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

# Listen for application traffic
resource "aws_alb_listener" "applications" {
  load_balancer_arn = aws_alb.ingress.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-2018-06"
  certificate_arn   = var.wildcard_arn

  # If no matches for applications, send to apex domain as fallback
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      host        = "${var.domain_name}"
      status_code = "HTTP_302"
    }
  }
}

# Security Group: world -> alb
resource "aws_security_group" "alb" {
  name_prefix = "app-alb-"
  vpc_id      = var.vpc_id

  tags = {
    env       = var.env
    terraform = "true"
    app       = "ingress"
    name      = "world->alb-ingress"
  }
}

locals {
  alb_ingress_ports = [80, 443]
}

// Allow inbound only to our listening port
resource "aws_security_group_rule" "lb_ingress" {
  count = length(local.alb_ingress_ports)

  type      = "ingress"
  from_port = local.alb_ingress_ports[count.index]
  to_port   = local.alb_ingress_ports[count.index]
  protocol  = "tcp"

  # If fronted by nginx, only accept traffic from inside the VPC
  cidr_blocks = var.public ? ["0.0.0.0/0"] : ["${var.cidr_block}/0"]

  security_group_id = aws_security_group.alb.id
}

// Allow all outbound by default
resource "aws_security_group_rule" "lb_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.alb.id
}
