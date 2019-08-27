#####
# Target group in case it needs to be attached to an LB
#####
locals {
  ingress_enabled = var.public ? 1 : 0
}

resource "aws_route53_record" "external" {
  count   = local.ingress_enabled
  zone_id = var.base.external.id
  name    = var.application_name
  type    = "CNAME"
  ttl     = 30

  records = ["ingress-${var.base.env}.${var.base.domain_name}"]
}

resource "aws_alb_target_group" "application" {
  count = local.ingress_enabled
  # max 6 characters for name prefix
  name_prefix = "app-lb"
  port        = var.application_ports[0]
  protocol    = "HTTP"
  vpc_id      = var.base.vpc.id
  target_type = "instance" # Must use instance for ASGs

  health_check {
    interval            = 60
    path                = var.health_check_path
    port                = var.application_ports[0]
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-308"
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = var.application_name
    name      = "app-lb-${var.application_name}-${var.application_ports[0]}"
  }
}

resource "aws_alb_listener_rule" "applications" {
  count        = local.ingress_enabled
  listener_arn = var.base.ingress.listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.application[0].arn
  }

  condition {
    field  = "host-header"
    values = ["${var.application_name}.${var.base.domain_name}"]
  }
}

# Allow ingress to talk to our primary port
resource "aws_security_group_rule" "ingress" {
  count                    = local.ingress_enabled
  type                     = "ingress"
  from_port                = var.application_ports[0]
  to_port                  = var.application_ports[0]
  protocol                 = "tcp"
  source_security_group_id = var.base.ingress.security_group.id

  security_group_id = aws_security_group.app.id
}
