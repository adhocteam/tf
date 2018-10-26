#######
# Teleport (https://gravitational.com/teleport/docs/intro/)
# provides SSH bastion services to connect to rest of infrastructure
#######

# Public DNS name for client use to connect to proxies
module "teleport_dns" {
  source = "../../dns_plus_cert"

  env         = "${var.env}"
  domain_name = "${var.domain_name}"
  subdomain   = "teleport.${var.env}"
  target      = "${aws_elb.proxy.dns_name}"
}

# Private DNS name inside VPC for auth nodes as light-weight service discovery
resource "aws_route53_zone" "teleport" {
  name    = "teleport.local"
  vpc_id  = "${data.aws_vpc.vpc.id}"
  comment = "${var.env} Teleport internal DNS"

  tags {
    env       = "${var.env}"
    terraform = "true"
    Name      = "teleport-dns"
  }
}

resource "aws_route53_record" "auth_internal" {
  zone_id = "$aws_route53_zone.teleport.id}"
  name    = "auth"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_lb.auth.dns_name}"]
}

# A create a random cluster token at creation time. No rotation as of now.
resource "random_string" "cluster_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret_version" "cluster_token" {
  secret_id     = "${var.env}/teleport/cluster_token"
  secret_string = "${random_string.cluster_token.result}"
}
