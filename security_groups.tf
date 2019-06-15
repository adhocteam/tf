
#######
# Security group for teleport proxy instances
#######

resource "aws_security_group" "teleport_proxies" {
  name_prefix = "tp-proxies-"
  vpc_id      = module.vpc.id

  tags = {
    env       = var.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-proxies"
  }
}

# Must allow talking to the world to call out to AWS APIs
resource "aws_security_group_rule" "proxy_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.teleport_proxies.id
}

#######
# Security group for teleport nodes 
#######

resource "aws_security_group" "teleport_nodes" {
  name_prefix = "tp-nodes-"
  vpc_id      = module.vpc.id

  tags = {
    env       = var.env
    terraform = "true"
    app       = "teleport"
    Name      = "teleport-nodes"
  }
}

# Must allow talking to the world to call out to AWS APIs
resource "aws_security_group_rule" "proxy_to_nodes" {
  type                     = "ingress"
  from_port                = 3022
  to_port                  = 3022
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.teleport_proxies.id

  security_group_id = aws_security_group.teleport_nodes.id
}

#######
# Security group for jumpbox to access the nodes 
#######

resource "aws_security_group" "jumpbox" {
  name_prefix = "jumpbox-"
  vpc_id      = module.vpc.id

  tags = {
    env       = var.env
    terraform = "true"
    app       = "utilities"
    Name      = "jumpbox"
  }
}

resource "aws_security_group_rule" "jumpbox_ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.jumpbox.id
}

resource "aws_security_group_rule" "jump_into_vpc" {
  type        = "egress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [module.vpc.cidr_block]

  security_group_id = aws_security_group.jumpbox.id
}

#######
# Security group for jumpbox to access the nodes 
#######

resource "aws_security_group" "jumpbox_nodes" {
  name_prefix = "jumpbox-nodes-"
  vpc_id      = module.vpc.id

  tags = {
    env       = var.env
    terraform = "true"
    app       = "utilities"
    Name      = "jumpbox-nodes"
  }
}
resource "aws_security_group_rule" "jumpbox_to_nodes" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.jumpbox.id

  security_group_id = aws_security_group.jumpbox_nodes.id
}
