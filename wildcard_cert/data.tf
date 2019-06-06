#######
### Lookup resources already created by foundation
#######

data "aws_route53_zone" "external" {
  name         = var.root_domain
  private_zone = false
}

