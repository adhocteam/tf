#######
# The proxy is what handles client connections from the main cluster and
# forwards to the private nodes.
# This is stateless and can horizontally scale.
#######

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
  })

  associate_public_ip_address = false
  subnet_id                   = element(var.base.vpc.application[*].id, count.index)
  vpc_security_group_ids = [
    var.base.security_groups["jumpbox_nodes"].id,
    var.base.security_groups["teleport_proxies"].id,
  ]

  lifecycle {
    ignore_changes        = [ami]
    create_before_destroy = true
  }

  depends_on = [aws_instance.auths]

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
