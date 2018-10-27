module "vpc" {
  source = "./vpc"

  env  = "${var.env}"
  cidr = "${var.cidr}"
}

module "encryptkey" {
  source = "./encryptkey"

  env = "${var.env}"
}

module "wildcard" {
  source = "./wildcard_cert"

  env         = "${var.env}"
  root_domain = "${var.domain_name}"
  domain      = "${var.domain_name}"
}
