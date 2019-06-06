#######
# Creates a DNS CNAME record for a subdomain and a certificate that is valid for it.
#######

resource "aws_acm_certificate" "domain" {
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]

  validation_method = "DNS"

  tags = {
    terraform = "true"
    env       = var.env
    Name      = "wildcard-${var.domain}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "domain" {
  certificate_arn         = aws_acm_certificate.domain.arn
  validation_record_fqdns = aws_route53_record.validation.*.fqdn
}

# Only need to validate the first record because the wildcard entry will use the same DNS record
resource "aws_route53_record" "validation" {
  count   = "2"
  name    = aws_acm_certificate.domain.domain_validation_options[count.index]["resource_record_name"]
  type    = aws_acm_certificate.domain.domain_validation_options[count.index]["resource_record_type"]
  zone_id = data.aws_route53_zone.external.id
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibilty in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  records = [aws_acm_certificate.domain.domain_validation_options[count.index]["resource_record_value"]]
  ttl     = 60
}

