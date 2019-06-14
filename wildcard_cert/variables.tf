variable "env" {
  type        = string
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  type        = string
  description = "the external domain name for reaching the public resources, e.g. domain.name. must already be in route53"
}
