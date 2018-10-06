module "vpc" {
  source = "./vpc"

  env  = "${var.env}"
  cidr = "${var.cidr}"
}

module "encryptkey" {
  source = "./encryptkey"

  env = "${var.env}"
}
