#######
# Creates a DNS CNAME record for a subdomain and a certificate that is valid for it.
#######

resource "aws_route53_record" "subdomain" {
  zone_id = "${data.aws_route53_zone.external.id}"
  name    = "${var.subdomain}"
  type    = "CNAME"
  ttl     = 30

  records = ["${var.target}"]
}

resource "aws_acm_certificate" "subdomain" {
  domain_name               = "${aws_route53_record.subdomain.fqdn}"
  subject_alternative_names = ["*.${aws_route53_record.subdomain.fqdn}"]

  validation_method = "DNS"

  tags {
    terraform = "true"
    env       = "${var.env}"
    Name      = "${var.subdomain}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "subdomain" {
  certificate_arn         = "${aws_acm_certificate.subdomain.arn}"
  validation_record_fqdns = ["${aws_route53_record.subdomain.fqdn}"]
}

resource "aws_route53_record" "validation" {
  name    = "${aws_acm_certificate.subdomain.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.subdomain.domain_validation_options.0.resource_record_type}"
  zone_id = "${aws_route53_zone.subdomain.id}"
  records = ["${aws_acm_certificate.subdomain.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}
