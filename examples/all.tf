locals {

    domain_name = "example.com"
}

module "base" {
  source = "../"

  env = "test"
  domain_name = "${local.domain_name}"
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