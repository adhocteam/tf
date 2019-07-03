#######
# Nginx Reverse Proxy to send data to our backends
#######

# Create ECR repo for docker image and provide cross account access if needed
resource "aws_ecr_repository" "nginx" {
  name = "ingress-${var.base.env}"
}

#####
# Create auto-scaling group for nginx proxies
#
# We cannot use fargate until it supports multiple inbound ports
#####

locals {
  ports         = [200, 443, 80]
  target_groups = zipmap(local.ports, module.nginx.target_group)
}

module "nginx" {
  source = "../autoscaling"

  base             = var.base
  application_name = "ingress_nginx"
  # application_ports = local.ports

  # user_data = templatefile("${path.module}/user_data.tmpl", {
  #   nginx_image = "${aws_ecr_repository.nginx.repository_url}:latest"
  #   ports       = local.ports
  # })
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

# TODO(bob) restrict this to just the one image
resource "aws_iam_role_policy_attachment" "nginx" {
  role       = module.nginx.instance_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
