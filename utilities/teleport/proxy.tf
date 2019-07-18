#######
# The proxy is what handles client connections from the internet and
# forwards to the private nodes. It also has a web interface.
# This is stateless and can horizontally scale behind the LB as needed
#######

#######
# Network load balancer that receives traffic from the internet
# Terminates our TLS for HTTPS traffic
#######

resource "aws_lb" "nlb" {
  name_prefix        = "tp-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.base.vpc.public[*].id

  enable_cross_zone_load_balancing = true

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-proxy-nlb"
  }
}

# HTTPS ports
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 443
  protocol          = "TLS"

  ssl_policy      = "ELBSecurityPolicy-FS-2018-06"
  certificate_arn = var.base.wildcard.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

resource "aws_lb_listener" "https_native" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 3080
  protocol          = "TLS"

  ssl_policy      = "ELBSecurityPolicy-FS-2018-06"
  certificate_arn = var.base.wildcard.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

resource "aws_lb_target_group" "https" {
  name_prefix = "in-tls"
  port        = 3080
  protocol    = "TCP"
  vpc_id      = var.base.vpc.id

  # Use IP to support Fargate clusters
  target_type = "ip"

  health_check {
    protocol = "TCP"
    port     = 3080
  }

  depends_on = [aws_lb.nlb]

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-proxy-https"
  }
}

# SSH inbound proxy
resource "aws_lb_listener" "proxy" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 3023
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy.arn
  }
}

resource "aws_lb_target_group" "proxy" {
  name_prefix = "in-tls"
  port        = 3023
  protocol    = "TCP"
  vpc_id      = var.base.vpc.id

  # Use IP to support Fargate clusters
  target_type = "ip"

  # Health check only on web port to prevent logs filling with connection resets
  health_check {
    protocol = "TCP"
    port     = 3080
  }

  depends_on = [aws_lb.nlb]

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-proxy-inbound-proxy"
  }
}

# SSH outbound reverse tunnel proxy
resource "aws_lb_listener" "tunnel" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 3024
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tunnel.arn
  }
}

resource "aws_lb_target_group" "tunnel" {
  name_prefix = "in-tls"
  port        = 3024
  protocol    = "TCP"
  vpc_id      = var.base.vpc.id

  # Use IP to support Fargate clusters
  target_type = "ip"

  # Health check only on web port to prevent logs filling with connection resets
  health_check {
    protocol = "TCP"
    port     = 3080
  }

  depends_on = [aws_lb.nlb]

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-proxy-reverse-tunnel"
  }
}

resource "aws_alb_target_group_attachment" "https" {
  count            = length(aws_instance.proxies[*].private_ip)
  target_group_arn = aws_lb_target_group.https.arn
  target_id        = aws_instance.proxies[count.index].private_ip
}

resource "aws_alb_target_group_attachment" "proxy" {
  count            = length(aws_instance.proxies[*].private_ip)
  target_group_arn = aws_lb_target_group.proxy.arn
  target_id        = aws_instance.proxies[count.index].private_ip
}

resource "aws_alb_target_group_attachment" "tunnel" {
  count            = length(aws_instance.proxies[*].private_ip)
  target_group_arn = aws_lb_target_group.tunnel.arn
  target_id        = aws_instance.proxies[count.index].private_ip
}

#######
# Proxy instances
#######

resource "aws_instance" "proxies" {
  count         = var.proxy_count
  ami           = var.base.ami.id
  instance_type = "t3.micro"
  key_name      = var.base.ssh_key

  user_data = templatefile("${path.module}/proxy-user-data.tmpl", {
    nodename      = "teleport-proxy-${count.index}"
    cluster_token = data.aws_secretsmanager_secret_version.cluster_token.secret_string
    proxy_domain  = aws_route53_record.public.fqdn
  })

  associate_public_ip_address = false

  subnet_id = element(var.base.vpc.application[*].id, count.index)
  vpc_security_group_ids = [
    var.base.security_groups["jumpbox_nodes"].id,
    aws_security_group.proxies.id
  ]

  lifecycle {
    ignore_changes        = [ami]
    create_before_destroy = true
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 20
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = {
    Name      = "teleport-proxy-${count.index}"
    app       = "teleport"
    env       = var.base.env
    terraform = "true"
  }
}


#######
### Security group for proxy instances
#######

resource "aws_security_group" "proxies" {
  name_prefix = "teleport-proxies-"
  vpc_id      = var.base.vpc.id

  tags = {
    env       = var.base.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-proxies"
  }
}

resource "aws_security_group_rule" "proxy_webui" {
  type        = "ingress"
  from_port   = 3080
  to_port     = 3080
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.proxies.id
}

resource "aws_security_group_rule" "proxy_ssh" {
  type        = "ingress"
  from_port   = 3023
  to_port     = 3023
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.proxies.id
}

resource "aws_security_group_rule" "proxy_cluster" {
  type        = "ingress"
  from_port   = 3024
  to_port     = 3024
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.proxies.id
}

# Must allow talking to the world to call out to AWS APIs
resource "aws_security_group_rule" "proxy_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.proxies.id
}

