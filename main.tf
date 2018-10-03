module "vpc" {
  source = "./vpc"

  name = "${var.name}"
  cidr = "${var.cidr}"
}

module "encryptkey" {
  source = "./encryptkey"

  name = "${var.name}"
}
