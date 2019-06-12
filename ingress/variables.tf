variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "other_accounts" {
  type        = list(string)
  description = "OPTIONAL: Additional accounts to give access to the docker repository housing ingress images"
  default     = []
}

