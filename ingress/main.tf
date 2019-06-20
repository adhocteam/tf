#######
# DNS Records for proxied site(s)
#######

terraform {
  required_version = ">= 0.12"
}

locals {
  ingress_dns_name = var.nginx ? aws_lb.nlb.dns_name : aws_alb.ingress.dns_name
}

resource "aws_route53_record" "external" {
  count   = length(var.applications)
  zone_id = var.base.external.id
  name    = var.applications[count.index].name
  type    = "CNAME"
  ttl     = 30

  records = [local.ingress_dns_name]
}

#######
# ALB in front of HTTP services
#######

resource "aws_route53_record" "alb_cname" {
  zone_id = var.base.vpc.internal.id
  name    = "ingress-alb"
  type    = "CNAME"
  ttl     = 30

  records = [aws_alb.application_alb.dns_name]
}

resource "aws_alb" "ingress" {
  # max 6 characters for name prefix
  name_prefix     = "in-alb"
  internal        = ! var.nginx
  security_groups = [aws_security_group.alb.id]
  subnets         = var.base.vpc.public[*]

  ip_address_type = "ipv4"

  tags = {
    env       = var.base.env
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
  certificate_arn   = var.base.wildcard.arn

  # If no matches for applications, send to apex domain as fallback
  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      host        = "${var.base.domain_name}"
      status_code = "HTTP_301"
    }
  }
}

# Set forwarding to each application
resource "aws_lb_listener_rule" "applications" {
  count        = length(var.applications)
  listener_arn = aws_alb_listener.applications.arn

  action {
    type             = "forward"
    target_group_arn = var.application[count.index].target_group.arn
  }

  condition {
    field  = "host-header"
    values = ["${var.applications[count.index].name}.${var.base.domain_name}"]
  }
}

# Security Group: world -> alb
resource "aws_security_group" "alb" {
  name_prefix = "app-alb-"
  vpc_id      = var.base.vpc.id

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "ingress"
    name      = "world->alb-ingress"
  }
}

locals {
  alb_ingress_ports = [80, 200, 443]
}

// Allow inbound only to our listening port
resource "aws_security_group_rule" "lb_ingress" {
  count = length(local.alb_ingress_ports)

  type      = "ingress"
  from_port = local.alb_ingress_ports[count.index]
  to_port   = local.alb_ingress_ports[count.index]
  protocol  = "tcp"

  source_security_group_id = var.nginx ? aws_security_group.nginx.id : null
  cidr_blocks              = var.nginx ? null : ["0.0.0.0/0"]

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
