#######
# Teleport (https://gravitational.com/teleport/docs/intro/)
# provides SSH bastion services to connect to rest of infrastructure
#
# This uses the 'trusted cluster' mechanism to create a "subcluster"
# only accessible via the main cluster. Intended use case is for higher
# environments where you do not want to have a public endpoint open.
#######

# Private DNS name inside VPC for auth nodes as light-weight service discovery
resource "aws_route53_zone" "teleport" {
  name    = "teleport.local"
  comment = "${var.env} Teleport internal DNS"

  vpc {
    vpc_id = data.aws_vpc.vpc.id
  }

  tags = {
    env       = var.env
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
