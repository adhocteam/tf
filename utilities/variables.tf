variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "region" {
  description = "the preferred AWS region for resources."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}
