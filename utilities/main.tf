locals {
  teleport = "${var.ssh_bastion >=1 ? 1 : 0}"
  jenkins  = "${var.jenkins >=1 ? 1 : 0}"
}

module "teleport" {
  count             = "${local.teleport}"
  source            = "./teleport"
  region            = "${var.region}"
  env               = "${var.env}"
  domain_name       = "${var.domain_name}"
  emergency_jumpbox = "${var.jumpbox}"
}

module "jenkins" {
  count       = "${local.jenkins}"
  source      = "./jenkins"
  env         = "${var.env}"
  domain_name = "${var.domain_name}"
}
