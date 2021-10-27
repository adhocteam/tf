#######
# Creates a DNS CNAME record for a subdomain and a certificate that is valid for it.
#######

terraform {
  required_version = ">= 0.12"
}

resource "aws_acm_certificate" "domain" {
  count                     = var.primary ? 1 : 0
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
  count                   = var.primary ? 1 : 0
  certificate_arn         = aws_acm_certificate.domain[0].arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

# Only need to validate the first record because the wildcard entry will use the same DNS record
resource "aws_route53_record" "validation" {
  for_each = var.primary ? {
    for dvo in aws_acm_certificate.domain[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
  name    = each.value.name
  type    = each.value.type
  zone_id = data.aws_route53_zone.external.id
  records = [each.value.record]
  ttl     = 60
}

