#######
# Teleport (https://gravitational.com/teleport/docs/intro/)
# provides SSH bastion services to connect to rest of infrastructure
#######

resource "aws_route53_record" "proxies_external" {
  zone_id = "${data.aws_route53_zone.external.id}"
  name    = "teleport-${var.env}"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_elb.proxy.dns_name}"]
}

resource "aws_route53_record" "auth_internal" {
  zone_id = "${data.aws_route53_zone.internal.id}"
  name    = "teleport-auth"
  type    = "CNAME"
  ttl     = 30

  records = ["${aws_lb.auth.dns_name}"]
}

resource "random_string" "cluster_token" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret_version" "cluster_token" {
  secret_id     = "${var.env}/teleport/cluster_token"
  secret_string = "${random_string.cluster_token.result}"
}
