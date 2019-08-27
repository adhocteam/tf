#######
### Lookup resources already created by foundation
#######

data "aws_route53_zone" "external" {
  name         = var.domain_name
  private_zone = false
}

data "aws_acm_certificate" "primary" {
  count  = var.primary ? 0 : 1
  domain = var.domain_name
}
