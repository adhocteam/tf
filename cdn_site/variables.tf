variable "env" {
  description = "the name of the environment, e.g. \"testing\". it must be unique in the account."
}

variable "subdomain" {
  default = "www"
}

variable "domain_name" {
  default = ""
}

