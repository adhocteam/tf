module "vpc-test" {
  source = "./vpc"

  env = "${var.env}"
  cidr = "${var.cidr}"
}

module "encryptkey" {
  source = "./encryptkey"

  env = "${var.env}"
}

module "utilities" {
  source = "./utilities"

  region      = "${var.region}"
  env        = "${var.env}"
  domain_name = "${var.domain_name}"
}
