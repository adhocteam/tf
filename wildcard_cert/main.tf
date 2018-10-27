#######
# Creates a DNS CNAME record for a subdomain and a certificate that is valid for it.
#######

resource "aws_acm_certificate" "domain" {
  domain_name               = "${var.domain}"
  subject_alternative_names = ["*.${var.domain}"]

  validation_method = "DNS"

  tags {
    terraform = "true"
    env       = "${var.env}"
    Name      = "wildcard-${var.domain}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "domain" {
  certificate_arn         = "${aws_acm_certificate.domain.arn}"
  validation_record_fqdns = ["${var.domain}"]
}

resource "aws_route53_record" "validation" {
  count   = "${length(aws_acm_certificate.domain.domain_validation_options)}"
  name    = "${element(aws_acm_certificate.domain.domain_validation_options.*.resource_record_name, count.index)}"
  type    = "${element(aws_acm_certificate.domain.domain_validation_options.*.resource_record_type, count.index)}"
  zone_id = "${data.aws_route53_zone.external.id}"
  records = ["${element(aws_acm_certificate.domain.domain_validation_options.*.resource_record_value, count.index)}"]
  ttl     = 60
}
