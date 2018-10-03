module "vpc" {
  source = "./vpc"

  name = "${var.name}"
  cidr = "${var.cidr}"
}

module "encryptkey" {
  source = "./encryptkey"

  name = "${var.name}"
}

module "utilities" {
  source = "./utilities"

  region      = "${var.region}"
  name        = "${var.name}"
  domain_name = "${var.domain_name}"
}
