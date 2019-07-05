#######
# Creates a DNS CNAME record for a subdomain and a certificate that is valid for it.
#######

terraform {
  required_version = ">= 0.12"
}

resource "aws_acm_certificate" "domain" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]

  validation_method = "DNS"

  tags = {
    terraform = "true"
    env       = var.env
    Name      = "wildcard-${var.domain_name}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "domain" {
  certificate_arn         = aws_acm_certificate.domain.arn
  validation_record_fqdns = aws_route53_record.validation[*].fqdn
}

# Only need to validate the first record because the wildcard entry will use the same DNS record
resource "aws_route53_record" "validation" {
  count   = "2"
  name    = aws_acm_certificate.domain.domain_validation_options[0]["resource_record_name"]
  type    = aws_acm_certificate.domain.domain_validation_options[0]["resource_record_type"]
  zone_id = data.aws_route53_zone.external.id
  records = [aws_acm_certificate.domain.domain_validation_options[0]["resource_record_value"]]
  ttl     = 60
}

