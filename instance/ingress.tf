#####
# Target group in case it needs to be attached to an LB
#####
resource "aws_route53_record" "external" {
  count   = length(var.ingress) > 0 ? 1 : 0
  zone_id = var.base.external.id
  name    = var.application_name
  type    = "CNAME"
  ttl     = 30

  records = [var.ingress.dns_record]
}

resource "aws_alb_target_group" "application" {
  count = length(var.ingress) > 0 ? 1 : 0
  # max 6 characters for name prefix
  name_prefix = "app-lb"
  port        = var.application_ports[0]
  protocol    = "HTTP"
  vpc_id      = var.base.vpc.id
  target_type = "ip" # Must use IP to support fargate

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

resource "aws_alb_target_group_attachment" "application" {
  count            = (length(var.ingress) > 0 ? 1 : 0) * length(aws_instance.box)
  target_group_arn = aws_alb_target_group.application[0].arn
  target_id        = aws_instance.box[count.index].private_ip
}

resource "aws_alb_listener_rule" "applications" {
  count        = length(var.ingress) > 0 ? 1 : 0
  listener_arn = var.ingress.listener.arn

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
  count                    = length(var.ingress) > 0 ? 1 : 0
  type                     = "ingress"
  from_port                = var.application_ports[0]
  to_port                  = var.application_ports[0]
  protocol                 = "tcp"
  source_security_group_id = var.ingress.security_group.id

  security_group_id = aws_security_group.app.id
}
