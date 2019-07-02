#######
# Teleport (https://gravitational.com/teleport/docs/intro/)
# provides SSH bastion services to connect to rest of infrastructure
#######

terraform {
  required_version = ">= 0.12"
}

# Public DNS name for client use to connect to proxies
resource "aws_route53_record" "public" {
  zone_id = var.base.external.id
  name    = "teleport"
  type    = "CNAME"
  ttl     = 30

  records = [aws_lb.nlb.dns_name]
}

# Private DNS name inside VPC for auth nodes as light-weight service discovery
resource "aws_route53_zone" "teleport" {
  name    = "teleport.local"
  comment = "${var.base.env} Teleport internal DNS"

  vpc {
    vpc_id = var.base.vpc.id
  }

  tags = {
    env       = var.base.env
    terraform = "true"
    Name      = "teleport-dns"
  }
}

resource "aws_route53_record" "auth_internal" {
  zone_id = aws_route53_zone.teleport.id
  name    = "auth"
  type    = "CNAME"
  ttl     = 30

  records = [aws_lb.auth.dns_name]
}

