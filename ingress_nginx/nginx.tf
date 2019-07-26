#######
# Nginx Reverse Proxy to send data to our backends
#######

#####
# Create auto-scaling group for nginx proxies
#
# We cannot use fargate until it supports multiple inbound ports
#####

data "aws_ami" "nginx" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["ingress_${var.base.env}*"]
  }
}

locals {
  ports = [200, 443, 80]
}

module "nginx" {
  source = "../autoscaling"

  base              = var.base
  ami_id            = data.aws_ami.nginx.id
  application_name  = "ingress_nginx"
  application_ports = local.ports
  target_group_arns = [aws_lb_target_group.http.arn, aws_lb_target_group.https.arn]
}

#TODO(bob) this may be able to be restricted to our private CIDR b/c we use proxy_protocol
resource "aws_security_group_rule" "nginx" {
  count       = length(local.ports)
  type        = "ingress"
  from_port   = local.ports[count.index]
  to_port     = local.ports[count.index]
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = module.nginx.security_group.id
}
