#######
# Teleport (https://gravitational.com/teleport/docs/intro/)
# provides SSH bastion services to connect to rest of infrastructure
#######

# Public DNS name for client use to connect to proxies
resource "aws_route53_record" "public" {
  zone_id = "${data.aws_route53_zone.external.id}"
  name    = "teleport.${var.env}"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_elb.proxy.dns_name}"]
}

module "cert" {
  source      = "../../wildcard_cert"
  env         = "${var.env}"
  root_domain = "${var.domain_name}"

  # Can't use aws_route53_record.public.fqdn here to prevent cycle with ELB
  domain = "teleport.${var.env}.${var.domain_name}"
}

# Private DNS name inside VPC for auth nodes as light-weight service discovery
resource "aws_route53_zone" "teleport" {
  name    = "teleport.local"
  comment = "${var.env} Teleport internal DNS"

  vpc {
    vpc_id = "${aws_vpc.primary.id}"
  }

  tags {
    env       = "${var.env}"
    terraform = "true"
    Name      = "teleport-dns"
  }
}

resource "aws_route53_record" "auth_internal" {
  zone_id = "${aws_route53_zone.teleport.id}"
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
