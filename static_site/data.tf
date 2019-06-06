# Pull in data from outside terraform (the public zone and certificate must already exist in the account)
data "aws_route53_zone" "domain" {
  name         = var.domain_name
  private_zone = false
}

data "aws_acm_certificate" "wildcard" {
  domain      = var.domain_name
  most_recent = true
}

