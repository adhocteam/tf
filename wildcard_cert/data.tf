#######
### Lookup resources already created by foundation
#######

data "aws_route53_zone" "external" {
  name         = var.domain_name
  private_zone = false
}

