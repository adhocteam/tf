variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "domain_name" {
  description = "the external domain name for reaching the public resources. must have a certificate in ACM associated with it."
}

variable "key_pair" {
  decription = "the name of the key pair that provides access to the jumpbox, defaults to infrastructure"
  default    = "infrastructure"
}
