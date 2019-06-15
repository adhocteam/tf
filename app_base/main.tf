#######
### Domain names
#######

resource "aws_route53_record" "external_cname" {
  zone_id = data.aws_route53_zone.external.id
  name    = var.application_name
  type    = "CNAME"
  ttl     = 30

  records = [aws_alb.application_alb.dns_name]
}

resource "aws_route53_record" "internal_cname" {
  zone_id = data.aws_route53_zone.internal.id
  name    = var.application_name
  type    = "CNAME"
  ttl     = 30

  records = [aws_alb.application_alb.dns_name]
}

#######
### Load balancer
#######

resource "aws_alb" "application_alb" {
  # max 6 characters for name prefix
  name_prefix     = "${format("%.5s", var.application_name)}-"
  internal        = false
  security_groups = [aws_security_group.application_alb_sg.id]
  subnets         = data.aws_subnet.public_subnet.*.id

  ip_address_type = "ipv4"

  tags = {
    env       = var.env
    terraform = "true"
    app       = var.application_name
    name      = "alb-${var.application_name}"
  }
}

# ALB target group and listeners
resource "aws_alb_target_group" "application_target_group" {
  # max 6 characters for name prefix
  name_prefix = "${format("%.5s", var.application_name)}-"
  port        = var.application_port
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.vpc.id
  target_type = "ip" # Must use IP to support fargate

  health_check {
    interval            = 60
    path                = var.health_check_path
    port                = var.application_port
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  depends_on = [aws_alb.application_alb]

  tags = {
    env       = var.env
    terraform = "true"
    app       = var.application_name
    name      = "alb-tg-${var.application_name}:${var.application_port}"
  }
}

resource "aws_alb_listener" "application_alb_https" {
  load_balancer_arn = aws_alb.application_alb.arn
  port              = var.loadbalancer_port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.wildcard.arn

  default_action {
    target_group_arn = aws_alb_target_group.application_target_group.arn
    type             = "forward"
  }
}

# Security Group: world -> alb
resource "aws_security_group" "application_alb_sg" {
  name_prefix = "${var.application_name}-alb-"
  vpc_id      = data.aws_vpc.vpc.id

  tags = {
    env       = var.env
    terraform = "true"
    app       = var.application_name
    name      = "world->alb-sg-${var.application_name}"
  }
}

// Allow inbound only to our listening port
resource "aws_security_group_rule" "lb_ingress" {
  type        = "ingress"
  from_port   = var.loadbalancer_port
  to_port     = var.loadbalancer_port
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.application_alb_sg.id
}

// Allow all outbound by default
resource "aws_security_group_rule" "lb_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.application_alb_sg.id
}

// Allow inbound only to our application port
resource "aws_security_group_rule" "app_ingress" {
  type                     = "ingress"
  from_port                = var.application_port
  to_port                  = var.application_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.application_alb_sg.id

  security_group_id = aws_security_group.app_sg.id
}

