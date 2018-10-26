variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "root_domain" {
  description = "the external domain name for reaching the public resources, e.g. domain.name. must already be in route53"
}

variable "domain" {
  description = "the Fully Qualified Domain Name for the new cert, e.g., beta.api.domain.name. Use .fqdn attribute from an aws_route53_record"
}
